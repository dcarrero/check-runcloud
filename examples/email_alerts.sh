#!/bin/bash

################################################################################
# Email Alert Wrapper for Server Analysis Script v3.0
# Author: David Carrero (https://carrero.es)
# Description: Runs server analysis and sends email alerts when issues detected
# Usage: Configure EMAIL_TO and add to crontab
# Compatible with: OpenLiteSpeed (lsphp) and Nginx (php-fpm)
################################################################################

set -euo pipefail

# Configuration
readonly EMAIL_TO="your-email@example.com"
readonly EMAIL_FROM="server-monitor@yourdomain.com"
readonly EMAIL_SUBJECT="Server Alert - High Resource Usage Detected"
readonly ANALYSIS_SCRIPT="/usr/local/bin/server-analysis"
readonly SCRIPT_VERSION="3.0.0"

# Alert thresholds
readonly MEMORY_ALERT_THRESHOLD=85
readonly DISK_ALERT_THRESHOLD=90

# Colors for logs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m'

# Detect web server type
detect_web_server() {
    if command -v /usr/local/lsws/bin/lswsctrl &> /dev/null || [[ -d "/usr/local/lsws" ]]; then
        echo "openlitespeed"
    elif command -v nginx &> /dev/null || systemctl list-units 2>/dev/null | grep -q nginx; then
        echo "nginx"
    else
        echo "unknown"
    fi
}

# Run the analysis script in non-interactive mode
run_analysis() {
    local temp_log="$1"
    # Run with --all flag for non-interactive execution
    "$ANALYSIS_SCRIPT" --all > "$temp_log" 2>&1
}

# Check if alerts should be sent
check_alerts() {
    local should_alert=false
    local alert_messages=""
    local web_server=$(detect_web_server)

    # Check memory usage
    local memory_usage=$(free | grep Mem | awk '{printf("%.0f", ($3/$2)*100)}')
    if [[ $memory_usage -gt $MEMORY_ALERT_THRESHOLD ]]; then
        should_alert=true
        alert_messages+="⚠️  ALERT: Memory usage is ${memory_usage}% (threshold: ${MEMORY_ALERT_THRESHOLD}%)\n"
    fi

    # Check disk usage
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -gt $DISK_ALERT_THRESHOLD ]]; then
        should_alert=true
        alert_messages+="⚠️  ALERT: Disk usage is ${disk_usage}% (threshold: ${DISK_ALERT_THRESHOLD}%)\n"
    fi

    # Check for long-running PHP processes (adapts to web server)
    local php_pattern
    local php_type
    if [[ "$web_server" == "openlitespeed" ]]; then
        php_pattern="lsphp"
        php_type="LSPHP"
    elif [[ "$web_server" == "nginx" ]]; then
        php_pattern="php-fpm"
        php_type="PHP-FPM"
    else
        php_pattern="php"
        php_type="PHP"
    fi

    local long_php=$(ps -eo etime,cmd | grep "$php_pattern" | grep -v grep | awk '{
        split($1, time, "-")
        if (length(time) > 1) print
        else {
            split($1, hms, ":")
            if (length(hms) == 3 && hms[1] >= 1) print
        }
    }' | wc -l)

    if [[ $long_php -gt 5 ]]; then
        should_alert=true
        alert_messages+="⚠️  ALERT: ${long_php} ${php_type} processes running longer than 1 hour\n"
    fi

    # Check for OOM killer activity
    if dmesg | grep -i "oom-kill" | grep -q "$(date +%b)" 2>/dev/null; then
        should_alert=true
        alert_messages+="⚠️  ALERT: OOM Killer was active recently\n"
    fi

    if [[ "$should_alert" == true ]]; then
        echo -e "$alert_messages"
        return 0
    else
        return 1
    fi
}

# Send email with analysis
send_email() {
    local alert_summary="$1"
    local latest_log
    local web_server=$(detect_web_server)

    # Safely find the latest log file
    latest_log=$(find /home/logs -name "server_analysis_*.log" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)

    # Validate log file exists and is readable
    if [[ -z "$latest_log" || ! -f "$latest_log" || ! -r "$latest_log" ]]; then
        echo "ERROR: No valid log file found" >&2
        return 1
    fi

    {
        echo "Server Analysis Alert v${SCRIPT_VERSION}"
        echo "========================================"
        echo "Author: David Carrero"
        echo "GitHub: https://github.com/dcarrero/check-runcloud"
        echo "========================================"
        echo ""
        echo "Server: $(hostname)"
        echo "Date: $(date)"
        echo "Web Server: ${web_server}"
        echo ""
        echo "$alert_summary"
        echo ""
        echo "Full analysis log attached below:"
        echo ""
        cat "$latest_log"
    } | mail -s "$EMAIL_SUBJECT" "$EMAIL_TO"
}

# Alternative: Send email using mailx
send_email_mailx() {
    local alert_summary="$1"
    local latest_log
    local web_server=$(detect_web_server)

    # Safely find the latest log file
    latest_log=$(find /home/logs -name "server_analysis_*.log" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)

    # Validate log file exists and is readable
    if [[ -z "$latest_log" || ! -f "$latest_log" || ! -r "$latest_log" ]]; then
        echo "ERROR: No valid log file found" >&2
        return 1
    fi

    {
        echo "Server Analysis Alert v${SCRIPT_VERSION}"
        echo "========================================"
        echo "Author: David Carrero"
        echo "GitHub: https://github.com/dcarrero/check-runcloud"
        echo "========================================"
        echo ""
        echo "Server: $(hostname)"
        echo "Date: $(date)"
        echo "Web Server: ${web_server}"
        echo ""
        echo "$alert_summary"
        echo ""
        echo "Full analysis log attached below:"
        echo ""
        cat "$latest_log"
    } | mailx -r "$EMAIL_FROM" -s "$EMAIL_SUBJECT" "$EMAIL_TO"
}

# Alternative: Send via SMTP (using sendemail)
send_email_smtp() {
    local alert_summary="$1"
    local latest_log
    local web_server=$(detect_web_server)

    # Safely find the latest log file
    latest_log=$(find /home/logs -name "server_analysis_*.log" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)

    # Validate log file exists and is readable
    if [[ -z "$latest_log" || ! -f "$latest_log" || ! -r "$latest_log" ]]; then
        echo "ERROR: No valid log file found" >&2
        return 1
    fi

    # Requires sendemail package: apt-get install sendemail
    # Configure these variables via environment or config file:
    local SMTP_SERVER="${SMTP_SERVER:-smtp.gmail.com:587}"
    local SMTP_USER="${SMTP_USER:-}"
    local SMTP_PASS="${SMTP_PASS:-}"

    # Validate credentials are set
    if [[ -z "$SMTP_USER" || -z "$SMTP_PASS" ]]; then
        echo "ERROR: Set SMTP_USER and SMTP_PASS environment variables" >&2
        echo "Example: export SMTP_USER=your@email.com SMTP_PASS=your-password" >&2
        return 1
    fi

    {
        echo "Server Analysis Alert v${SCRIPT_VERSION}"
        echo "========================================"
        echo "Author: David Carrero"
        echo "GitHub: https://github.com/dcarrero/check-runcloud"
        echo "========================================"
        echo ""
        echo "Server: $(hostname)"
        echo "Date: $(date)"
        echo "Web Server: ${web_server}"
        echo ""
        echo "$alert_summary"
    } | sendemail \
        -f "$EMAIL_FROM" \
        -t "$EMAIL_TO" \
        -u "$EMAIL_SUBJECT" \
        -s "$SMTP_SERVER" \
        -xu "$SMTP_USER" \
        -xp "$SMTP_PASS" \
        -o tls=yes \
        -a "$latest_log"
}

main() {
    # Create secure temporary file
    local temp_log
    temp_log=$(mktemp /tmp/server_analysis_check.XXXXXX) || {
        echo "ERROR: Cannot create temporary file" >&2
        exit 1
    }

    # Ensure cleanup on exit
    trap 'rm -f "$temp_log"' EXIT INT TERM HUP

    echo -e "${GREEN}Running server analysis...${NC}"

    # Run analysis
    run_analysis "$temp_log"

    # Check if alerts needed
    if check_alerts; then
        echo -e "${RED}Issues detected! Sending email alert...${NC}"

        # Get alert summary
        alert_summary=$(check_alerts)

        # Choose your email method (uncomment one):
        send_email "$alert_summary"
        # send_email_mailx "$alert_summary"
        # send_email_smtp "$alert_summary"

        echo -e "${GREEN}Alert email sent to $EMAIL_TO${NC}"
    else
        echo -e "${GREEN}No issues detected. No alert needed.${NC}"
    fi

    # Cleanup handled by trap
}

main "$@"
