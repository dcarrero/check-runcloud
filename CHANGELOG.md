# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0] - 2025-11-12

### Added
- **Multi-language Support (i18n)**: English and Spanish support
  - Automatic language detection based on system locale
  - Interactive language toggle (option 'i' in menu)
  - Complete translations for menu, checks, and messages
  - Default to Spanish if system is in Spanish, English otherwise
- **Automatic Web Server Detection**: Detects OpenLiteSpeed or Nginx
  - Shows detected web server in menu
  - Adapts all checks and analysis to detected server
- **Nginx Support**: Full support for Nginx + PHP-FPM stacks
  - `analyze_nginx_processes()` - Nginx and PHP-FPM process analysis
  - `analyze_phpfpm_cpu()` - PHP-FPM CPU usage monitoring
  - `analyze_nginx_logs()` - Nginx error log analysis
  - PHP-FPM specific recommendations
- **Author Information Display**:
  - Author name and website shown in interactive menu
  - Author information included in email alerts
- **Enhanced email_alerts.sh**:
  - Updated to use non-interactive mode (`--all` flag)
  - Web server detection for adaptive PHP process monitoring
  - Works with both lsphp (OpenLiteSpeed) and php-fpm (Nginx)
  - Author and web server info included in alert emails
  - Version tracking (v3.0.0)

### Changed
- Script version updated to 3.0.0
- Web server functions now auto-detect and adapt:
  - `analyze_webserver_processes()` - Routes to OLS or Nginx specific function
  - `analyze_php_cpu()` - Detects lsphp or php-fpm
  - `analyze_webserver_logs()` - Routes to appropriate log files
- Menu structure redesigned to show:
  - Author information (David Carrero - https://carrero.es)
  - Detected web server
  - Dynamic server-specific check names
- Language toggle added to menu (option 'i')
- All user-facing text supports translations

### Improved
- Better compatibility with different RunCloud setups
- More flexible for various server configurations
- Enhanced user experience with native language support
- Clearer attribution and contact information
- More accurate process detection for different PHP handlers

### Documentation
- Updated README with acknowledgments:
  - Stackscale (private cloud infrastructure provider)
  - Color Vivo (RunCloud server access for testing)
- Updated examples showing both OLS and Nginx usage
- Added language selection documentation

## [2.0.0] - 2025-11-12

### Added
- **Interactive Menu System**: User-friendly menu for selecting which checks to run
  - Select individual checks (1-10)
  - Run all checks at once (option 0)
  - Toggle logging on/off interactively (option l)
  - Multiple selection support (comma or space-separated)
- **Command-Line Mode**: Non-interactive operation for automation
  - `-1` to `-10` flags for running specific checks
  - `--all` or `-a` to run all checks
  - `--no-log` to disable log file creation
  - `--help` accessible without root privileges
- **Smart Recommendations**: Context-aware, actionable recommendations for each check
  - Severity-based alerts (Critical, Warning, Success)
  - Specific commands and configuration suggestions
  - Memory usage recommendations
  - Load average analysis
  - CPU usage alerts for PHP processes
  - Long-running process detection with kill suggestions
  - Database connection pool warnings
  - Disk space cleanup commands
  - Network connection analysis
  - OOM killer event detection
- **Flexible Logging**: Toggle logging on/off
  - Enabled by default
  - Can be disabled via command-line flag or interactive menu
  - All output respects logging preference

### Changed
- Script version updated to 2.0.0
- Main execution flow now supports both interactive and non-interactive modes
- Help system accessible without requiring root privileges
- Logging is now optional instead of mandatory
- All `tee` commands now respect the `ENABLE_LOGGING` flag
- Function architecture refactored for better modularity

### Improved
- Better user experience with colored, organized output
- More actionable recommendations based on actual metrics
- Clearer separation between different operation modes
- Enhanced flexibility for automation and manual use
- More granular control over which checks to run

### Documentation
- Updated README with interactive menu examples
- Added command-line usage examples
- Updated feature list with new capabilities
- Added check number reference guide
- Updated example output to show recommendations

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

[3.0.0]: https://github.com/dcarrero/check-runcloud/releases/tag/v3.0.0
[2.0.0]: https://github.com/dcarrero/check-runcloud/releases/tag/v2.0.0
[1.2.0]: https://github.com/dcarrero/check-runcloud/releases/tag/v1.2.0
[1.1.0]: https://github.com/dcarrero/check-runcloud/releases/tag/v1.1.0
[1.0.0]: https://github.com/dcarrero/check-runcloud/releases/tag/v1.0.0
