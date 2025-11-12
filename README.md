# Server Analysis Script for RunCloud + OpenLiteSpeed + MySQL/MariaDB

A comprehensive monitoring and diagnostics tool for web servers running **RunCloud**, **OpenLiteSpeed**, and **MySQL/MariaDB**. This script helps identify performance bottlenecks, resource issues, and provides actionable recommendations.

## Features

- **System Resource Monitoring**: CPU, memory, swap, and load average tracking
- **OpenLiteSpeed Analysis**: Process monitoring and error log analysis
- **PHP Process Tracking**: Identify long-running PHP processes (LSPHP)
- **MySQL/MariaDB Diagnostics**:
  - Automatic detection of MySQL or MariaDB
  - Active connections and queries
  - InnoDB status and configuration
  - Slow query log analysis
- **Network Statistics**: Connection states (ESTABLISHED, TIME_WAIT, CLOSE_WAIT)
- **Disk Space Monitoring**: Storage usage alerts
- **System Logs**: Recent database logs and OOM killer messages
- **Automated Alerts**: Warnings for high memory/disk usage
- **Detailed Logging**: Timestamped logs for historical analysis

## Requirements

- **OS**: Linux (Ubuntu/Debian recommended)
- **Privileges**: Root access (sudo)
- **Stack**: RunCloud + OpenLiteSpeed + MySQL/MariaDB
- **Dependencies**:
  - `bash` (version 4.0+)
  - `mysql-client` or `mariadb-client` (auto-detected)
  - `net-tools` (for netstat)
  - `systemd` (for journalctl)

## Installation

### Method 1: Automated Installer (Recommended)

```bash
# Download and run the installer
curl -fsSL https://raw.githubusercontent.com/dcarrero/check-runcloud/main/install.sh | sudo bash
```

Or download and inspect first:

```bash
# Download installer
curl -O https://raw.githubusercontent.com/dcarrero/check-runcloud/main/install.sh

# Review the installer
cat install.sh

# Run it
sudo bash install.sh
```

The installer will:
- Check and install dependencies (mysql-client or mariadb-client, net-tools)
- Install the script to `/usr/local/bin/server-analysis`
- Create log directory `/home/logs`
- Optionally set up cron jobs for automated monitoring

### Method 2: Manual Installation

```bash
# Download the script
curl -O https://raw.githubusercontent.com/dcarrero/check-runcloud/main/server_analysis.sh

# Make it executable
chmod +x server_analysis.sh

# Run it
sudo ./server_analysis.sh
```

### Method 3: System-wide Installation

```bash
# Copy to system binaries
sudo cp server_analysis.sh /usr/local/bin/server-analysis

# Make executable
sudo chmod +x /usr/local/bin/server-analysis

# Run from anywhere
sudo server-analysis
```

### Method 4: Clone Repository

```bash
# Clone the repository
git clone https://github.com/dcarrero/check-runcloud.git
cd check-runcloud

# Run installer
sudo bash install.sh

# Or run directly
sudo bash server_analysis.sh
```

## Usage

### Basic Usage

```bash
sudo ./server_analysis.sh
```

### Output

The script generates:
1. **Console output**: Real-time colored output for quick review
2. **Log file**: Saved in `/home/logs/server_analysis_YYYYMMDD_HHMMSS.log`

### Example Output

```
========== SERVER ANALYSIS: RUNCLOUD + OPENLITESPEED + MYSQL/MARIADB ==========
Script Version: 1.0.0
Timestamp: 2025-11-12 10:30:45

[1] SYSTEM RESOURCES
=====================================
CPU, Memory and Swap Usage:
              total        used        free      shared  buff/cache   available
Mem:           15Gi       8.2Gi       2.1Gi       324Mi       5.4Gi       6.8Gi
Swap:         2.0Gi       512Mi       1.5Gi

System Load Average:  2.15, 1.89, 1.56
CPU Cores: 8

[2] OPENLITESPEED PROCESSES
=====================================
...

[5] MYSQL/MARIADB ANALYSIS
=====================================
Database Type: MariaDB
Client: mariadb
Socket: /run/mysqld/mysqld.sock
...
```

## Automation

### Cron Job Setup

Monitor your server automatically at regular intervals:

```bash
# Edit crontab
sudo crontab -e

# Run every 30 minutes (during troubleshooting)
*/30 * * * * /usr/local/bin/server-analysis > /dev/null 2>&1

# Or run every hour (for regular monitoring)
0 * * * * /usr/local/bin/server-analysis > /dev/null 2>&1

# Or run daily at 3 AM
0 3 * * * /usr/local/bin/server-analysis > /dev/null 2>&1
```

### Email Alerts (Advanced)

Automatically receive email notifications when critical issues are detected.

#### Option 1: Use the Email Alert Wrapper

```bash
# Copy the email alert example
cp examples/email_alerts.sh /usr/local/bin/server-analysis-alert

# Edit configuration
sudo nano /usr/local/bin/server-analysis-alert
# Change EMAIL_TO to your email address

# Make executable
sudo chmod +x /usr/local/bin/server-analysis-alert

# Add to crontab instead of regular analysis
sudo crontab -e
# Add: 0 * * * * /usr/local/bin/server-analysis-alert
```

Features of the email alert wrapper:
- Only sends emails when thresholds are exceeded
- Includes memory, disk, and process monitoring
- Detects OOM killer activity
- Includes full analysis in email body

#### Option 2: Simple Email on Every Run

```bash
# Install mailutils
sudo apt-get install mailutils

# Modify cron job to send email
0 * * * * /usr/local/bin/server-analysis && mail -s "Server Analysis Report" your@email.com < $(ls -t /home/logs/server_analysis_*.log | head -1)
```

#### Option 3: SMTP Configuration

For Gmail or other SMTP servers, see `examples/email_alerts.sh` for detailed configuration.

## Understanding the Output

### Key Sections

#### 1. System Resources
- **Memory > 85%**: Consider upgrading RAM or optimizing applications
- **High Load Average**: Should be less than CPU core count

#### 2. LSPHP Processes
- **Long-running processes (> 60s)**: Indicates slow PHP code or database queries
- **High CPU usage**: May need code optimization or caching

#### 3. MySQL/MariaDB Analysis
- **Database type**: Shows whether MySQL or MariaDB is detected
- **Active queries > 5s**: Likely needs query optimization or indexes
- **Max connections**: Ensure limit is not being reached
- **InnoDB buffer pool**: Should be ~70% of available RAM

#### 4. Slow Query Log
- Identifies specific queries that need optimization
- Add indexes or refactor problem queries

### Common Issues and Solutions

| Issue | Possible Cause | Solution |
|-------|---------------|----------|
| Memory > 90% | Insufficient RAM | Upgrade server or optimize apps |
| LSPHP > 60s | Slow queries/code | Check slow query log, profile PHP |
| High disk usage | Logs or uploads | Clean old files, rotate logs |
| Many TIME_WAIT | High traffic | Normal, but ensure keep-alive is configured |
| OOM killer active | Memory exhausted | Increase RAM or reduce app memory |

## Configuration

### Customizing Thresholds

Edit the script to adjust alert thresholds:

```bash
# Line ~15-17
readonly MEMORY_THRESHOLD=85  # Change to 90 for less sensitive alerts
readonly DISK_THRESHOLD=90
readonly LONG_PROCESS_THRESHOLD=60  # PHP processes in seconds
```

### Custom Log Directory

```bash
# Line ~13
readonly LOG_DIR="/home/logs"  # Change to your preferred location
```

## Troubleshooting

### Permission Denied

```bash
# Ensure you're running as root
sudo ./server_analysis.sh
```

### MySQL/MariaDB Socket Not Found

```bash
# Manually check socket location
find /run /var/run -name "mysqld.sock"

# The script auto-detects the socket, but you can verify it's accessible
ls -la /run/mysqld/mysqld.sock
# or
ls -la /var/run/mysqld/mysqld.sock
```

### MySQL/MariaDB Client Not Found

```bash
# Install the appropriate client
# For MariaDB:
sudo apt-get install mariadb-client

# For MySQL:
sudo apt-get install mysql-client

# The script will automatically detect which one is available
```

### OpenLiteSpeed Logs Not Found

```bash
# Check your OpenLiteSpeed installation path
ls -la /usr/local/lsws/logs/

# Update paths in script (line ~268)
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/improvement`)
3. Commit your changes (`git commit -am 'Add new feature'`)
4. Push to the branch (`git push origin feature/improvement`)
5. Open a Pull Request

### Development Guidelines

- Maintain POSIX compliance where possible
- Add comments for complex logic
- Test on Ubuntu 20.04/22.04 and Debian 11/12
- Update README for new features

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

**David Carrero**
- Website: [carrero.es](https://carrero.es)
- GitHub: [@dcarrero](https://github.com/dcarrero)

## Acknowledgments

- Designed for servers managed with [RunCloud](https://runcloud.io)
- Optimized for [OpenLiteSpeed](https://openlitespeed.org)
- MySQL/MariaDB diagnostics based on best practices
- Compatible with both MySQL and MariaDB databases

## Support

If you find this script helpful, please:
- Star the repository
- Report issues on GitHub
- Share with others who might benefit

## Changelog

### Version 1.0.0 (2025-11-12)
- Initial release
- Basic system resource monitoring
- OpenLiteSpeed process analysis
- MariaDB diagnostics
- Automated alerting system

## FAQ

**Q: Can I use this on cPanel/Plesk servers?**
A: This script is specifically designed for RunCloud + OpenLiteSpeed. For other control panels, modifications will be needed.

**Q: How much disk space do logs consume?**
A: Each analysis generates ~100-500KB. For hourly runs, expect ~10-50MB per month.

**Q: Is this safe to run on production servers?**
A: Yes, the script only reads data and doesn't modify any configurations. It uses `set -euo pipefail` for safety.

**Q: Can I run this without RunCloud?**
A: Yes, it works with any OpenLiteSpeed + MySQL/MariaDB setup. RunCloud-specific features are minimal.

**Q: Does it work with MySQL or only MariaDB?**
A: It works with both! The script automatically detects whether you have MySQL or MariaDB installed and uses the appropriate client.

---

**Made with care for the web hosting community** 🚀
