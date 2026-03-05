#!/usr/bin/env bash
#
# vt-actions.sh - Helper functions for handling VirusTotal scan results
#
# Provides functions to:
# - Tag files with scan results
# - Lock down malicious files
# - Quarantine files with restricted permissions
#

QUARANTINE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/virustotal-quarantine"
VT_TAG_CLEAN="vt-clean"
VT_TAG_MALICIOUS="vt-malicious"

# Tag a file as clean
# Args: file_path
tag_file_clean() {
    local file="$1"
    
    # KDE Plasma 6 uses xattr for tags
    if command -v setfattr &>/dev/null; then
        # Remove malicious tag
        setfattr -x user.xdg.tags 2>/dev/null "$file" || true
        # Set clean tag
        setfattr -n user.xdg.tags -v "$VT_TAG_CLEAN" "$file" 2>/dev/null || true
    fi
    
    # Restore normal permissions if they were restricted
    chmod u+w "$file" 2>/dev/null
}

# Tag a file as malicious and lock it down
# Args: file_path
tag_file_malicious() {
    local file="$1"
    
    # KDE Plasma 6 uses xattr for tags
    if command -v setfattr &>/dev/null; then
        # Set malicious tag
        setfattr -n user.xdg.tags -v "$VT_TAG_MALICIOUS" "$file" 2>/dev/null || true
    fi
    
    # Remove execute permissions for all
    chmod a-x "$file" 2>/dev/null
    
    # Make read-only (owner can still delete)
    chmod a-w "$file" 2>/dev/null
    chmod u+r "$file" 2>/dev/null
    
    # Store original permissions in extended attributes (if supported)
    if command -v setfattr &>/dev/null; then
        local perms
        perms=$(stat -c "%a" "$file" 2>/dev/null)
        setfattr -n user.vt.original_perms -v "$perms" "$file" 2>/dev/null
    fi
    
    # Mark scan time
    if command -v setfattr &>/dev/null; then
        local timestamp
        timestamp=$(date +%s)
        setfattr -n user.vt.scan_time -v "$timestamp" "$file" 2>/dev/null
        setfattr -n user.vt.status -v "malicious" "$file" 2>/dev/null
    fi
}

# Quarantine a file - move it to restricted directory
# Args: file_path
# Returns: 0 on success, 1 on failure
quarantine_file() {
    local file="$1"
    local filename
    filename=$(basename "$file")
    local dest="$QUARANTINE_DIR/$filename"
    
    # Create quarantine directory with restricted permissions
    if [[ ! -d "$QUARANTINE_DIR" ]]; then
        mkdir -p "$QUARANTINE_DIR"
        chmod 700 "$QUARANTINE_DIR"  # Only owner can access
    fi
    
    # Handle duplicate filenames
    local counter=1
    while [[ -e "$dest" ]]; do
        local base="${filename%.*}"
        local ext="${filename##*.}"
        if [[ "$base" == "$ext" ]]; then
            # No extension
            dest="$QUARANTINE_DIR/${filename}_${counter}"
        else
            dest="$QUARANTINE_DIR/${base}_${counter}.${ext}"
        fi
        ((counter++))
    done
    
    # Move file to quarantine
    if mv "$file" "$dest" 2>/dev/null; then
        # Set strict permissions: read-only, no execute
        chmod 400 "$dest"
        
        # Tag as quarantined using xattr
        if command -v setfattr &>/dev/null; then
            setfattr -n user.xdg.tags -v "vt-quarantined,$VT_TAG_MALICIOUS" "$dest" 2>/dev/null || true
        fi
        
        # Store quarantine metadata
        if command -v setfattr &>/dev/null; then
            local timestamp
            timestamp=$(date +%s)
            setfattr -n user.vt.quarantine_time -v "$timestamp" "$dest" 2>/dev/null
            setfattr -n user.vt.original_path -v "$file" "$dest" 2>/dev/null
            setfattr -n user.vt.status -v "quarantined" "$dest" 2>/dev/null
        fi
        
        echo "$dest"
        return 0
    else
        echo "" >&2
        return 1
    fi
}

# Restore a file from quarantine (use with extreme caution)
# Args: quarantined_file_path
# Returns: 0 on success, 1 on failure
restore_from_quarantine() {
    local file="$1"
    
    # Safety check
    if [[ "$file" != "$QUARANTINE_DIR"/* ]]; then
        echo "Error: File is not in quarantine directory" >&2
        return 1
    fi
    
    # Try to get original path
    local original_path=""
    if command -v getfattr &>/dev/null; then
        original_path=$(getfattr -n user.vt.original_path --only-values "$file" 2>/dev/null)
    fi
    
    # If no original path, restore to home directory
    if [[ -z "$original_path" ]] || [[ "$original_path" == "-" ]]; then
        original_path="$HOME/$(basename "$file")"
    fi
    
    # Check if destination exists
    if [[ -e "$original_path" ]]; then
        echo "Error: Destination already exists: $original_path" >&2
        return 1
    fi
    
    # Restore original permissions if available
    local original_perms=""
    if command -v getfattr &>/dev/null; then
        original_perms=$(getfattr -n user.vt.original_perms --only-values "$file" 2>/dev/null)
    fi
    
    # Move file back
    if mv "$file" "$original_path" 2>/dev/null; then
        # Restore permissions
        if [[ -n "$original_perms" ]] && [[ "$original_perms" != "-" ]]; then
            chmod "$original_perms" "$original_path" 2>/dev/null
        else
            chmod 644 "$original_path" 2>/dev/null
        fi
        
        # Remove quarantine tags using xattr
        if command -v setfattr &>/dev/null; then
            setfattr -x user.xdg.tags "$original_path" 2>/dev/null || true
        fi
        
        # Clean up xattr
        if command -v setfattr &>/dev/null; then
            setfattr -x user.vt.quarantine_time "$original_path" 2>/dev/null
            setfattr -x user.vt.original_path "$original_path" 2>/dev/null
            setfattr -n user.vt.status -v "restored" "$original_path" 2>/dev/null
        fi
        
        echo "$original_path"
        return 0
    else
        echo "" >&2
        return 1
    fi
}

# List quarantined files
list_quarantine() {
    if [[ ! -d "$QUARANTINE_DIR" ]]; then
        echo "Quarantine directory is empty"
        return
    fi
    
    echo "Quarantined files in: $QUARANTINE_DIR"
    echo "----------------------------------------"
    
    local count=0
    for file in "$QUARANTINE_DIR"/*; do
        if [[ -f "$file" ]]; then
            ((count++))
            local filename
            filename=$(basename "$file")
            local size
            size=$(du -h "$file" | cut -f1)
            
            # Get quarantine time if available
            local quarantine_time="Unknown"
            if command -v getfattr &>/dev/null; then
                local timestamp
                timestamp=$(getfattr -n user.vt.quarantine_time --only-values "$file" 2>/dev/null)
                if [[ -n "$timestamp" ]] && [[ "$timestamp" != "-" ]]; then
                    quarantine_time=$(date -d "@$timestamp" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$timestamp")
                fi
            fi
            
            echo "$count. $filename ($size) - quarantined: $quarantine_time"
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        echo "No files in quarantine"
    fi
}

# Check if required tools are available
check_dependencies() {
    local missing=()
    
    if ! command -v balooctl6 &>/dev/null; then
        missing+=("balooctl6 (KDE Baloo indexing)")
    fi
    
    if ! command -v setfattr &>/dev/null; then
        echo "Warning: setfattr not found - extended attributes will not be stored" >&2
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Error: Missing required tools:" >&2
        printf '  - %s\n' "${missing[@]}" >&2
        return 1
    fi
    
    return 0
}

# Export functions if sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f tag_file_clean
    export -f tag_file_malicious
    export -f quarantine_file
    export -f restore_from_quarantine
    export -f list_quarantine
    export -f check_dependencies
fi
