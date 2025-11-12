# Security Policy

## Reporting Security Vulnerabilities

If you discover a security vulnerability in this project, please email the details to the repository owner. Please do not create a public issue for security vulnerabilities.

## Security Guarantees

### Read-Only Analysis

The main analysis script (`server_analysis.sh`) is **completely read-only** and makes NO modifications to your system:

- ✅ Only reads files and system information
- ✅ Only executes SELECT queries on the database (no INSERT, UPDATE, DELETE)
- ✅ Does NOT modify any configuration files
- ✅ Does NOT delete or move files
- ✅ Only creates log files in `/home/logs/`

### No Credentials Stored

- ✅ No database credentials required (uses socket authentication)
- ✅ No passwords stored in scripts
- ✅ Email credentials use environment variables (not hardcoded)
- ✅ SMTP passwords should be set via environment, not in files

## Security Measures Implemented

### Version 1.2.0 Security Improvements

1. **Command Injection Protection**
   - Fixed unsafe `ls` command usage that could lead to command injection
   - Replaced with safe `find` command with proper validation
   - All file paths validated before use

2. **Credential Management**
   - Removed hardcoded example credentials from SMTP configuration
   - SMTP credentials now use environment variables
   - Clear error messages when credentials are missing

3. **Secure Temporary Files**
   - Replaced predictable `/tmp` paths with `mktemp` random suffixes
   - Added signal handlers for cleanup (EXIT, INT, TERM, HUP)
   - Temporary files automatically removed on script exit

4. **Database Query Protection**
   - Added 10-second connection timeout to all MySQL/MariaDB queries
   - Prevents script hanging on database issues
   - Graceful error handling for connection failures

5. **Input Validation**
   - User input in installer is sanitized
   - Only valid characters accepted (Y/N for yes/no, 1-4 for choices)
   - Prevents injection through user input

6. **File Access Controls**
   - File existence, readability, and type validated before reading
   - Prevents path traversal attacks
   - Error handling for inaccessible files

## Security Best Practices

### For Users

1. **Run as Root (Required)**
   ```bash
   sudo ./server_analysis.sh
   ```
   This is required to read system logs and database sockets.

2. **Protect Log Files**
   ```bash
   chmod 700 /home/logs
   ```
   Log files may contain sensitive information about your system.

3. **Use Environment Variables for Credentials**
   ```bash
   export SMTP_USER="your-email@example.com"
   export SMTP_PASS="your-app-password"
   ./email_alerts.sh
   ```
   Never hardcode credentials in scripts.

4. **Review Before Running**
   Always review scripts before running them with sudo:
   ```bash
   cat server_analysis.sh
   ```

5. **Verify Script Integrity**
   ```bash
   # Check the script hasn't been tampered with
   sha256sum server_analysis.sh
   ```

### For Developers

1. **Never Use `eval`**
   - This codebase does not use `eval` anywhere
   - Any PR introducing `eval` will be rejected

2. **Quote All Variables**
   ```bash
   # Good
   cp "$file" "$destination"

   # Bad
   cp $file $destination
   ```

3. **Validate All Inputs**
   ```bash
   # Always sanitize user input
   input="${input//[^a-zA-Z0-9]/}"
   ```

4. **Use `readonly` for Constants**
   ```bash
   readonly CONFIG_FILE="/etc/myapp/config"
   ```

5. **Set Safe Defaults**
   ```bash
   set -euo pipefail
   ```

## Known Limitations

1. **Requires Root Access**
   - Script needs sudo to read system logs and database sockets
   - This is by design and necessary for functionality

2. **Database Socket Detection**
   - Auto-detects MySQL/MariaDB socket location
   - May fail on non-standard installations
   - Check `/run` and `/var/run` manually if detection fails

3. **Email Alerts Require Configuration**
   - Email functionality requires mail/mailx/sendemail to be installed
   - SMTP credentials must be provided via environment variables

## Security Changelog

### v1.2.0 (2025-11-12)
- Fixed command injection in email_alerts.sh
- Removed hardcoded credentials
- Implemented secure temporary file handling
- Added database query timeouts
- Implemented input validation

### v1.1.0 (2025-11-12)
- Added MySQL/MariaDB auto-detection
- No security issues identified

### v1.0.0 (2025-11-12)
- Initial release
- Basic security measures in place

## Compliance

This script follows security best practices:
- OWASP secure coding guidelines
- CWE (Common Weakness Enumeration) mitigation
- shellcheck static analysis compliance
- Principle of least privilege
- Defense in depth

## Security Testing

Recommended security testing tools:

```bash
# Static analysis
shellcheck server_analysis.sh
shellcheck install.sh
shellcheck examples/email_alerts.sh

# Check for hardcoded secrets
grep -r "password\|secret\|key" *.sh

# Verify permissions
stat -c "%a %n" *.sh
```

## Contact

For security concerns, contact:
- **Author**: David Carrero
- **Website**: https://carrero.es
- **GitHub**: https://github.com/dcarrero/check-runcloud

---

**Last Updated**: 2025-11-12
**Security Review**: Complete
**Status**: Production Ready
