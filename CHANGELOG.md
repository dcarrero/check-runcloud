# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2025-11-12

### Security Fixes
- **CRITICAL**: Fixed command injection vulnerability in `email_alerts.sh` where `ls` output could be exploited (CVE-like severity: HIGH)
- **CRITICAL**: Removed hardcoded credentials from SMTP example configuration
- **HIGH**: Replaced predictable temporary file path with secure `mktemp` implementation
- **HIGH**: Added file validation before `cat` operations to prevent path traversal
- **MEDIUM**: Added connection timeouts (10s) to all MySQL/MariaDB queries to prevent hanging
- **MEDIUM**: Added input sanitization for user responses in installer

### Improved
- All constants in `email_alerts.sh` now use `readonly` modifier for immutability
- Added signal handlers (EXIT, INT, TERM, HUP) for proper cleanup of temporary files
- SMTP credentials now use environment variables instead of hardcoded values
- Enhanced error messages with better context
- Safer file discovery using `find` with validation instead of `ls` with globs

### Changed
- Email alert script now requires `SMTP_USER` and `SMTP_PASS` environment variables for SMTP method
- Temporary files now created in `/tmp` with random suffixes for security
- User input in installer is now validated and sanitized

### Documentation
- Added security documentation about read-only nature of analysis script
- Updated installation instructions with security best practices
- Added environment variable configuration examples

## [1.1.0] - 2025-11-12

### Added
- Full MySQL support in addition to MariaDB
- Automatic detection of database type (MySQL vs MariaDB)
- Smart client detection (prefers `mariadb` command, falls back to `mysql`)
- Database type display in analysis output
- Support for both `mariadb.service` and `mysql.service` in system logs

### Changed
- Updated all function names to be database-agnostic (e.g., `find_mysql_socket` instead of `find_mariadb_socket`)
- Renamed `analyze_mariadb()` to `analyze_database()` for clarity
- Updated installer to detect and install appropriate database client
- Updated all documentation to reflect MySQL/MariaDB support

### Improved
- Better error messages when database client is not found
- More robust database service detection in installer
- Enhanced system log analysis to check both MySQL and MariaDB services

## [1.0.0] - 2025-11-12

### Added
- Initial release of Server Analysis Script
- System resource monitoring (CPU, memory, swap, load average)
- OpenLiteSpeed process monitoring
- LSPHP process tracking with CPU usage analysis
- Detection of long-running PHP processes (>60 seconds)
- MySQL/MariaDB diagnostics:
  - Automatic detection of MySQL or MariaDB
  - Auto-detection of appropriate client (mysql or mariadb command)
  - Database type identification
  - Active connections and queries
  - Connection statistics by user
  - InnoDB status and configuration variables
  - Slow query log analysis
- System log analysis:
  - MySQL/MariaDB journal logs (auto-detects service name)
  - OOM killer messages
- OpenLiteSpeed error log monitoring
- Network statistics (ESTABLISHED, TIME_WAIT, CLOSE_WAIT connections)
- Disk space monitoring
- Automated alerting for high memory usage (>85%)
- Automated alerting for high disk usage (>90%)
- Timestamped log files for historical analysis
- Color-coded terminal output
- Comprehensive recommendations based on analysis
- MIT License
- README with installation and usage instructions
- Contributing guidelines
- Automated installer script
- Email alert example script

### Features
- Automatic MySQL/MariaDB socket detection
- Smart database client detection (mysql or mariadb command)
- Database type identification (MySQL vs MariaDB)
- Safe execution with `set -euo pipefail`
- Modular function-based architecture
- Cross-platform support (Ubuntu/Debian)
- Root privilege checking
- Detailed error handling

### Documentation
- Complete README with examples and troubleshooting
- FAQ section
- Contributing guidelines
- Code of conduct
- Example email alert configuration
- Installation guide

[1.2.0]: https://github.com/dcarrero/check-runcloud/releases/tag/v1.2.0
[1.1.0]: https://github.com/dcarrero/check-runcloud/releases/tag/v1.1.0
[1.0.0]: https://github.com/dcarrero/check-runcloud/releases/tag/v1.0.0
