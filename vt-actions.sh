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
AUDIT_LOG_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/virustotal-shell/audit"
VT_TAG_CLEAN="vt-clean"
VT_TAG_MALICIOUS="vt-malicious"

# Log an audit entry - tracks file by hash across locations
# Args: action, file_path, result, extra_data (comma-separated key=value pairs)
log_audit() {
    local action="$1"
    local file_path="$2"
    local result="$3"
    local extra_data="${4:-}"
    
    # Create audit log directory
    if [[ ! -d "$AUDIT_LOG_DIR" ]]; then
        mkdir -p "$AUDIT_LOG_DIR"
        chmod 700 "$AUDIT_LOG_DIR"
    fi
    
    # Calculate file hash (key for audit log)
    local file_hash="unknown"
    local file_size=0
    local filename="unknown"
    if [[ -f "$file_path" ]]; then
        file_hash=$(sha256sum "$file_path" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
        file_size=$(stat -c "%s" "$file_path" 2>/dev/null || echo "0")
        filename=$(basename "$file_path")
    fi
    
    # Generate timestamps
    local timestamp
    timestamp=$(date +%s)
    local datetime
    datetime=$(date -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S")
    
    # Log file based on hash (same file = same audit log)
    local log_file="$AUDIT_LOG_DIR/${file_hash}.json"
    
    # Build extra JSON properties
    local extra_json=""
    if [[ -n "$extra_data" ]]; then
        IFS=',' read -ra PAIRS <<< "$extra_data"
        for pair in "${PAIRS[@]}"; do
            if [[ "$pair" =~ ^([^=]+)=(.*)$ ]]; then
                local key="${BASH_REMATCH[1]}"
                local value="${BASH_REMATCH[2]}"
                # Escape for JSON
                value="${value//\\/\\\\}"
                value="${value//\"/\\\"}"
                extra_json="${extra_json},\"${key}\":\"${value}\""
            fi
        done
    fi
    
    # Create action entry with location
    local action_json
    action_json=$(cat <<ACTIONEOF
{"timestamp":$timestamp,"datetime":"$datetime","action":"$action","file_path":"$file_path","result":"$result"${extra_json}}
ACTIONEOF
)
    
    # Update or create JSON audit file
    if [[ -f "$log_file" ]] && command -v jq &>/dev/null; then
        # File exists, append action using jq
        local temp_file="${log_file}.tmp"
        jq --argjson action "$action_json" '.actions += [$action]' "$log_file" > "$temp_file" 2>/dev/null
        if [[ $? -eq 0 ]]; then
            mv "$temp_file" "$log_file"
        else
            # jq failed, recreate file
            rm -f "$temp_file"
            cat > "$log_file" <<EOF
{"file_hash":"$file_hash","filename":"$filename","file_size":$file_size,"first_seen":$timestamp,"actions":[$action_json]}
EOF
        fi
    else
        # Create new JSON file
        cat > "$log_file" <<EOF
{"file_hash":"$file_hash","filename":"$filename","file_size":$file_size,"first_seen":$timestamp,"actions":[$action_json]}
EOF
    fi
    
    chmod 600 "$log_file"
}

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
    
    # Log action
    log_audit "tag_clean" "$file" "success" "tag=$VT_TAG_CLEAN"
}

# Tag a file as malicious and lock it down
# Args: file_path, vt_detections (optional)
tag_file_malicious() {
    local file="$1"
    local vt_detections="${2:-unknown}"
    
    # Get original permissions
    local original_perms
    original_perms=$(stat -c "%a" "$file" 2>/dev/null || echo "644")
    
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
        setfattr -n user.vt.original_perms -v "$original_perms" "$file" 2>/dev/null
    fi
    
    # Mark scan time
    if command -v setfattr &>/dev/null; then
        local timestamp
        timestamp=$(date +%s)
        setfattr -n user.vt.scan_time -v "$timestamp" "$file" 2>/dev/null
        setfattr -n user.vt.status -v "malicious" "$file" 2>/dev/null
    fi
    
    # Log action
    log_audit "tag_malicious" "$file" "success" "tag=$VT_TAG_MALICIOUS,detections=$vt_detections,original_perms=$original_perms"
}

# Quarantine a file - move it to restricted directory, named by hash
# Args: file_path
# Returns: 0 on success, 1 on failure
quarantine_file() {
    local file="$1"
    local filename
    filename=$(basename "$file")
    
    # Create quarantine directory with restricted permissions
    if [[ ! -d "$QUARANTINE_DIR" ]]; then
        mkdir -p "$QUARANTINE_DIR"
        chmod 700 "$QUARANTINE_DIR"  # Only owner can access
    fi
    
    # Calculate file hash for unique naming
    local file_hash
    file_hash=$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1)
    if [[ -z "$file_hash" ]]; then
        echo "Error: Failed to calculate file hash" >&2
        return 1
    fi
    
    # Get original permissions and path before moving
    local original_perms
    original_perms=$(stat -c "%a" "$file" 2>/dev/null || echo "644")
    local original_path
    original_path=$(realpath "$file" 2>/dev/null || echo "$file")
    
    # Quarantine file named by full hash (prevents collisions, links to audit log)
    local dest="$QUARANTINE_DIR/${file_hash}"
    
    # If file already quarantined, just update audit log
    if [[ -f "$dest" ]]; then
        log_audit "quarantine" "$dest" "duplicate" "original_path=$original_path,original_perms=$original_perms,note=already_quarantined"
        rm -f "$file"  # Remove the duplicate
        echo "$dest"
        return 0
    fi
    
    # Move file to quarantine
    if mv "$file" "$dest" 2>/dev/null; then
        # Set strict permissions: read-only, no execute
        chmod 400 "$dest"
        
        # Tag as quarantined using xattr
        if command -v setfattr &>/dev/null; then
            setfattr -n user.xdg.tags -v "vt-quarantined,$VT_TAG_MALICIOUS" "$dest" 2>/dev/null || true
        fi
        
        # Log quarantine action with metadata
        log_audit "quarantine" "$dest" "success" "original_path=$original_path,original_perms=$original_perms,quarantine_path=$dest,original_filename=$filename,file_hash=$file_hash"
        
        echo "$dest"
        return 0
    else
        log_audit "quarantine" "$file" "failed" "error=mv_failed"
        echo "" >&2
        return 1
    fi
}

# Get quarantine metadata from JSON audit log
# Args: quarantined_file_path
# Returns: original_path and original_perms via stdout as "path|perms"
get_quarantine_metadata() {
    local file="$1"
    
    # Extract hash from quarantined filename (full SHA256 hash)
    local file_hash
    file_hash=$(basename "$file")
    
    if [[ -z "$file_hash" ]]; then
        echo "|644"
        return 1
    fi
    
    local log_file="$AUDIT_LOG_DIR/${file_hash}.json"
    
    if [[ ! -f "$log_file" ]] || ! command -v jq &>/dev/null; then
        echo "|644"
        return 1
    fi
    
    # Get the most recent quarantine action for this file
    local original_path
    local original_perms
    original_path=$(jq -r --arg qpath "$file" '.actions[] | select(.action=="quarantine" and (.quarantine_path==$qpath or .file_path==$qpath)) | .original_path' "$log_file" 2>/dev/null | tail -1)
    original_perms=$(jq -r --arg qpath "$file" '.actions[] | select(.action=="quarantine" and (.quarantine_path==$qpath or .file_path==$qpath)) | .original_perms' "$log_file" 2>/dev/null | tail -1)
    
    if [[ -z "$original_path" ]]; then
        original_path=""
    fi
    if [[ -z "$original_perms" ]] || [[ "$original_perms" == "null" ]]; then
        original_perms="644"
    fi
    
    echo "${original_path}|${original_perms}"
    return 0
}

# Restore a file from quarantine (use with extreme caution)
# Args: quarantined_file_path
# Returns: 0 on success, 1 on failure
restore_from_quarantine() {
    local file="$1"
    
    # Safety check
    if [[ "$file" != "$QUARANTINE_DIR"/* ]]; then
        echo "Error: File is not in quarantine directory" >&2
        log_audit "restore" "$file" "failed" "error=not_in_quarantine"
        return 1
    fi
    
    # Read metadata from audit log
    local metadata
    metadata=$(get_quarantine_metadata "$file")
    local original_path
    original_path=$(echo "$metadata" | cut -d'|' -f1)
    local original_perms
    original_perms=$(echo "$metadata" | cut -d'|' -f2)
    
    # If no original path, restore to home directory
    if [[ -z "$original_path" ]]; then
        original_path="$HOME/$(basename "$file")"
    fi
    
    # Check if destination exists
    if [[ -e "$original_path" ]]; then
        echo "Error: Destination already exists: $original_path" >&2
        log_audit "restore" "$file" "failed" "error=destination_exists,destination=$original_path"
        return 1
    fi
    
    # Move file back
    if mv "$file" "$original_path" 2>/dev/null; then
        # Restore permissions
        chmod "$original_perms" "$original_path" 2>/dev/null
        
        # Remove quarantine tags using xattr
        if command -v setfattr &>/dev/null; then
            setfattr -x user.xdg.tags "$original_path" 2>/dev/null || true
        fi
        
        # Update status in xattr
        if command -v setfattr &>/dev/null; then
            setfattr -n user.vt.status -v "restored" "$original_path" 2>/dev/null || true
        fi
        
        # Log restore action
        log_audit "restore" "$original_path" "success" "from_quarantine=$file,restored_perms=$original_perms"
        
        echo "$original_path"
        return 0
    else
        log_audit "restore" "$file" "failed" "error=mv_failed,destination=$original_path"
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
    
    # Check if quarantine is on tmpfs
    local fs_type
    fs_type=$(stat -f -c "%T" "$QUARANTINE_DIR" 2>/dev/null)
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                            QUARANTINED FILES                                 ║"
    echo "╠══════════════════════════════════════════════════════════════════════════════╣"
    if [[ "$fs_type" == "tmpfs" ]]; then
        printf "║  %-75s║\n" "Storage: TMPFS (files will be LOST on reboot)"
        echo "╠══════════════════════════════════════════════════════════════════════════════╣"
    fi
    printf "║  %-75s║\n" "Location: $QUARANTINE_DIR"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    
    local count=0
    for file in "$QUARANTINE_DIR"/*; do
        if [[ -f "$file" ]]; then
            ((count++))
            local filename
            filename=$(basename "$file")
            local size
            size=$(du -h "$file" | cut -f1)
            
            # Filename is the full hash
            local file_hash="$filename"
            local quarantine_time="Unknown"
            local original_file="Unknown"
            local original_path="Unknown"
            
            # Find matching audit log
            if command -v jq &>/dev/null; then
                local log_file="$AUDIT_LOG_DIR/${file_hash}.json"
                
                if [[ -f "$log_file" ]]; then
                    # Get original filename from audit log
                    original_file=$(jq -r '.filename' "$log_file" 2>/dev/null)
                    if [[ -z "$original_file" ]] || [[ "$original_file" == "null" ]]; then
                        original_file="Unknown"
                    fi
                    
                    # Get most recent quarantine timestamp and original path
                    local timestamp
                    timestamp=$(jq -r --arg qpath "$file" '.actions[] | select(.action=="quarantine" and .quarantine_path==$qpath) | .timestamp' "$log_file" 2>/dev/null | tail -1)
                    if [[ -n "$timestamp" ]] && [[ "$timestamp" != "null" ]]; then
                        quarantine_time=$(date -d "@$timestamp" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$timestamp")
                    fi
                    
                    # Get original path
                    original_path=$(jq -r --arg qpath "$file" '.actions[] | select(.action=="quarantine" and .quarantine_path==$qpath) | .original_path' "$log_file" 2>/dev/null | tail -1)
                    if [[ -z "$original_path" ]] || [[ "$original_path" == "null" ]]; then
                        original_path="Unknown"
                    fi
                fi
            fi
            
            # Print formatted entry
            echo ""
            printf "[%d] \\033[1m%s\\033[0m\\n" "$count" "$original_file"
            printf "    Size:         %s\\n" "$size"
            printf "    Hash:         %s\\n" "$file_hash"
            printf "    Quarantined:  %s\\n" "$quarantine_time"
            printf "    From:         %s\\n" "$original_path"
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        echo ""
        echo "No files in quarantine"
    else
        echo ""
        echo "───────────────────────────────────────────────────────────────────────────────"
        printf "Total: %d file(s)\n" "$count"
    fi
    echo ""
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
    export -f log_audit
    export -f tag_file_clean
    export -f tag_file_malicious
    export -f quarantine_file
    export -f get_quarantine_metadata
    export -f restore_from_quarantine
    export -f list_quarantine
    export -f check_dependencies
fi
