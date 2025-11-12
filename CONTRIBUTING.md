# Contributing to Server Analysis Script

Thank you for considering contributing to this project! This document outlines the process and guidelines for contributing.

## How to Contribute

### Reporting Bugs

If you find a bug, please create an issue on GitHub with:

- A clear, descriptive title
- Steps to reproduce the issue
- Expected behavior vs actual behavior
- Your environment (OS, versions, etc.)
- Relevant log output or screenshots

### Suggesting Enhancements

Enhancement suggestions are welcome! Please create an issue with:

- A clear description of the enhancement
- Why this would be useful
- Any implementation ideas you have

### Pull Requests

1. **Fork the repository** and create your branch from `main`
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Follow the coding style of the project
   - Add comments for complex logic
   - Test your changes thoroughly

3. **Commit your changes**
   ```bash
   git commit -m "Add: brief description of your changes"
   ```

   Use conventional commit messages:
   - `Add:` for new features
   - `Fix:` for bug fixes
   - `Update:` for improvements
   - `Docs:` for documentation
   - `Refactor:` for code restructuring

4. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

5. **Open a Pull Request** with:
   - Clear description of changes
   - Reference to related issues
   - Test results if applicable

## Development Guidelines

### Code Style

- Use **4 spaces** for indentation (not tabs)
- Keep lines under **100 characters** when possible
- Use **meaningful variable names**
- Add **comments** for non-obvious code
- Follow **bash best practices**:
  - Use `set -euo pipefail`
  - Quote variables: `"$var"`
  - Use `readonly` for constants
  - Use `local` for function variables

### Testing

Before submitting a PR:

1. Test on a clean Ubuntu/Debian system
2. Verify all script sections work correctly
3. Check for shellcheck warnings:
   ```bash
   shellcheck server_analysis.sh
   ```
4. Test with and without RunCloud
5. Ensure log files are created properly

### Documentation

- Update README.md if adding features
- Add inline comments for complex logic
- Update CHANGELOG.md with your changes
- Include examples when relevant

## Project Structure

```
.
├── server_analysis.sh   # Main script
├── README.md           # Documentation
├── LICENSE             # MIT License
├── CONTRIBUTING.md     # This file
├── .gitignore         # Git ignore rules
└── examples/          # Example configurations (if added)
```

## What We're Looking For

### High Priority

- Support for additional web servers (Apache, Nginx)
- Email notification system
- Alerting thresholds configuration file
- Performance optimizations
- Better error handling
- Additional diagnostics sections

### Medium Priority

- Web interface for viewing logs
- Historical data analysis
- Comparison between runs
- Export to JSON/CSV
- Integration with monitoring tools (Prometheus, etc.)

### Low Priority

- Color scheme customization
- Multiple language support
- Plugin system for custom checks

## Questions?

Feel free to open an issue for any questions about contributing.

## Code of Conduct

### Our Standards

- Be respectful and inclusive
- Accept constructive criticism gracefully
- Focus on what's best for the community
- Show empathy towards others

### Unacceptable Behavior

- Harassment or discriminatory language
- Personal attacks
- Trolling or insulting comments
- Publishing others' private information

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing! 🎉
