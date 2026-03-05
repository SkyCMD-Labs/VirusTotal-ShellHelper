# Contributing

Thank you for your interest in contributing to VirusTotal Shell Helper!

## Ways to Contribute

- **Report bugs** — open an issue using the bug report template
- **Suggest features** — open an issue using the feature request template
- **Test on other distros/DEs** — report your experience in Discussions
- **Improve docs** — fix typos, add examples, clarify instructions
- **Submit code** — open a pull request

## Getting Started

```bash
git clone https://github.com/SkyCMD-Labs/VirusTotal-ShellHelper.git
cd VirusTotal-ShellHelper
```

No build step needed — it's a bash script.

## Guidelines

### Code Style

- Follow existing bash patterns in `vt-check` and `install.sh`
- Use `local` for all function variables
- Add comments for non-obvious logic
- Test with `bash -n` to check for syntax errors:
  ```bash
  bash -n vt-check
  bash -n install.sh
  ```

### Commits

- Use clear, descriptive commit messages
- One logical change per commit
- Reference issues where relevant: `Fixes #123`

### Pull Requests

- Keep PRs focused — one feature or fix per PR
- Update relevant docs in `docs/` if your change affects behaviour
- Test on your system before submitting
- Fill out the pull request template

### Testing

Since there are no automated tests, please manually verify:

1. The happy path — file already in VT, hash lookup works
2. Upload path — new file, waits for analysis
3. `--no-wait` flag
4. `--notify` flag with your notification backend
5. Error cases — missing file, bad API key

## Reporting Bugs

Please include:
- OS and distribution
- Desktop environment and file manager
- Exact command run
- Full terminal output
- Expected vs actual behaviour

## Platform Testing

We especially welcome reports and fixes for:
- Distros other than Arch-based
- GNOME, XFCE, MATE, Cinnamon desktops
- ARM architecture

Open a Discussion to share your testing results!

## License

By contributing, you agree your contributions will be licensed under the MIT License.
