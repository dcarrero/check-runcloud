#!/bin/bash

################################################################################
# Server Analysis Script for RunCloud + OpenLiteSpeed + MySQL/MariaDB
# Author: David Carrero (https://carrero.es)
# Description: Comprehensive monitoring and diagnostics tool for web servers
# Usage: sudo ./server_analysis.sh
# License: MIT
################################################################################

set -euo pipefail

# Configuration
readonly SCRIPT_VERSION="1.2.0"
readonly TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
readonly LOG_DIR="/home/logs"
readonly LOGFILE="${LOG_DIR}/server_analysis_$(date +%Y%m%d_%H%M%S).log"

# Color codes for terminal output
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Alert thresholds
readonly MEMORY_THRESHOLD=85
readonly DISK_THRESHOLD=90
readonly LONG_PROCESS_THRESHOLD=60

################################################################################
# Helper Functions
################################################################################

log() {
    echo -e "$1" | tee -a "$LOGFILE"
}

log_section() {
    log "\n${GREEN}[$1]${NC}"
    log "====================================="
}

log_error() {
    log "${RED}ERROR: $1${NC}"
}

log_warning() {
    log "${YELLOW}WARNING: $1${NC}"
}

log_success() {
    log "${GREEN}✓ $1${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root (use sudo)"
        exit 1
    fi
}

create_log_dir() {
    mkdir -p "$LOG_DIR"
}

################################################################################
# Analysis Functions
################################################################################

analyze_system_resources() {
    log_section "1. SYSTEM RESOURCES"

    log "CPU, Memory and Swap Usage:"
    free -h | tee -a "$LOGFILE"
    log ""

    local load_avg=$(uptime | awk -F'load average:' '{ print $2 }')
    log "System Load Average: $load_avg"

    local cpu_cores=$(nproc)
    log "CPU Cores: $cpu_cores"
    log ""
}

analyze_openlitespeed() {
    log_section "2. OPENLITESPEED PROCESSES"

    log "Main OpenLiteSpeed processes:"
    ps aux | grep -E "openlitespeed|lsphp" | grep -v grep | tee -a "$LOGFILE" || log "No OpenLiteSpeed processes found"
    log ""
}

analyze_lsphp_cpu() {
    log_section "3. TOP 15 LSPHP PROCESSES BY CPU USAGE"

    ps aux --sort=-%cpu | grep lsphp | grep -v grep | head -15 | tee -a "$LOGFILE" || log "No LSPHP processes found"
    log ""
}

analyze_long_running_php() {
    log_section "4. LSPHP PROCESSES RUNNING > ${LONG_PROCESS_THRESHOLD} SECONDS"

    ps -eo pid,etime,vsz,rss,%cpu,%mem,cmd | grep lsphp | grep -v grep | awk -v threshold="$LONG_PROCESS_THRESHOLD" '
        BEGIN {
            print "PID\t\tTIME\t\tVSZ\tRSS\t%CPU\t%MEM\tCOMMAND"
            found=0
        }
        {
            split($2, time, "-")
            show=0

            if (length(time) > 1) {
                # Format: DD-HH:MM:SS (running for days)
                show=1
            } else {
                split($2, hms, ":")
                if (length(hms) == 3) {
                    # Format: HH:MM:SS
                    if (hms[1] >= 1 || (hms[1] == 0 && hms[2] >= 1)) {
                        show=1
                    }
                } else if (length(hms) == 2) {
                    # Format: MM:SS
                    if (hms[1] >= 1) {
                        show=1
                    }
                }
            }

            if (show) {
                print $0
                found=1
            }
        }
        END {
            if (found == 0) {
                print "No long-running processes found"
            }
        }
    ' | tee -a "$LOGFILE"
    log ""
}

find_mysql_socket() {
    local socket
    socket=$(find /run /var/run -name "mysqld.sock" 2>/dev/null | head -1)
    echo "$socket"
}

detect_mysql_client() {
    # Detect which MySQL client is available
    if command -v mariadb &> /dev/null; then
        echo "mariadb"
    elif command -v mysql &> /dev/null; then
        echo "mysql"
    else
        echo ""
    fi
}

detect_db_type() {
    # Detect if it's MySQL or MariaDB based on version string
    local mysql_socket="$1"
    local mysql_client="$2"

    if [[ -n "$mysql_client" && -n "$mysql_socket" ]]; then
        local version=$($mysql_client -S "$mysql_socket" -e "SELECT VERSION();" 2>/dev/null | tail -1)
        if [[ "$version" =~ MariaDB ]]; then
            echo "MariaDB"
        else
            echo "MySQL"
        fi
    else
        echo "Unknown"
    fi
}

analyze_database() {
    log_section "5. MYSQL/MARIADB ANALYSIS"

    local mysql_socket
    local mysql_client
    local db_type

    mysql_socket=$(find_mysql_socket)
    mysql_client=$(detect_mysql_client)

    if [[ -z "$mysql_socket" ]]; then
        log_error "MySQL/MariaDB socket not found"
        return 1
    fi

    if [[ -z "$mysql_client" ]]; then
        log_error "MySQL/MariaDB client not found (install mysql-client or mariadb-client)"
        return 1
    fi

    db_type=$(detect_db_type "$mysql_socket" "$mysql_client")

    log "Database Type: $db_type"
    log "Client: $mysql_client"
    log "Socket: $mysql_socket"
    log ""

    # Database Status
    log "Database Status:"
    $mysql_client -S "$mysql_socket" --connect-timeout=10 -e "STATUS\G" 2>/dev/null | tee -a "$LOGFILE" || log_error "Cannot connect to database"
    log ""

    # Active Processes
    log "Active database processes (> 5 seconds):"
    $mysql_client -S "$mysql_socket" --connect-timeout=10 -e "
    SELECT
        ID,
        USER,
        HOST,
        DB,
        TIME,
        STATE,
        SUBSTR(INFO, 1, 80) AS QUERY
    FROM INFORMATION_SCHEMA.PROCESSLIST
    WHERE TIME > 5 AND COMMAND != 'Sleep'
    ORDER BY TIME DESC
    \G" 2>/dev/null | tee -a "$LOGFILE" || log_error "Cannot query processlist"
    log ""

    # Connections by User
    log "Active connections by user:"
    $mysql_client -S "$mysql_socket" --connect-timeout=10 -e "
    SELECT
        USER,
        COUNT(*) as CONNECTIONS,
        SUM(IF(TIME > 30, 1, 0)) as OVER_30S,
        MAX(TIME) as MAX_TIME
    FROM INFORMATION_SCHEMA.PROCESSLIST
    GROUP BY USER
    ORDER BY CONNECTIONS DESC
    \G" 2>/dev/null | tee -a "$LOGFILE"
    log ""

    # Critical Variables
    log "Critical InnoDB variables:"
    $mysql_client -S "$mysql_socket" --connect-timeout=10 -e "
    SHOW VARIABLES WHERE Variable_name IN (
        'max_connections',
        'max_user_connections',
        'innodb_buffer_pool_size',
        'innodb_log_file_size',
        'query_cache_type',
        'query_cache_size',
        'tmp_table_size',
        'max_heap_table_size',
        'long_query_time',
        'slow_query_log'
    )
    \G" 2>/dev/null | tee -a "$LOGFILE"
    log ""

    # InnoDB Status
    log "InnoDB Status (first 80 lines):"
    $mysql_client -S "$mysql_socket" --connect-timeout=10 -e "SHOW ENGINE INNODB STATUS\G" 2>/dev/null | head -80 | tee -a "$LOGFILE"
    log ""
}

analyze_slow_queries() {
    log_section "6. SLOW QUERY LOG"

    local mysql_socket
    local mysql_client

    mysql_socket=$(find_mysql_socket)
    mysql_client=$(detect_mysql_client)

    if [[ -z "$mysql_socket" || -z "$mysql_client" ]]; then
        log_error "Cannot check slow query log - Database socket or client not found"
        return 1
    fi

    local slow_log_path
    slow_log_path=$($mysql_client -S "$mysql_socket" --connect-timeout=10 2>/dev/null -e "SHOW VARIABLES LIKE 'slow_query_log_file'" | tail -1 | awk '{print $2}')

    if [[ -f "$slow_log_path" ]]; then
        log "Last 30 lines of slow query log:"
        tail -30 "$slow_log_path" 2>/dev/null | tee -a "$LOGFILE"
    else
        log "Slow query log not found or not accessible"
    fi
    log ""
}

analyze_openlitespeed_logs() {
    log_section "7. OPENLITESPEED LOGS"

    local ols_error_log="/usr/local/lsws/logs/error.log"
    local ols_access_log="/usr/local/lsws/logs/access.log"

    if [[ -f "$ols_error_log" ]]; then
        log "Last 20 OpenLiteSpeed errors:"
        tail -20 "$ols_error_log" | tee -a "$LOGFILE"
    else
        log "OpenLiteSpeed error log not found at $ols_error_log"
    fi
    log ""
}

analyze_system_logs() {
    log_section "8. RECENT SYSTEM LOGS"

    log "Database logs (last 2 hours):"
    # Try MariaDB first, then MySQL
    if journalctl -u mariadb --since "2 hours ago" -n 1 2>/dev/null | grep -q "Logs begin"; then
        journalctl -u mariadb --since "2 hours ago" -n 20 2>/dev/null | tee -a "$LOGFILE"
    elif journalctl -u mysql --since "2 hours ago" -n 1 2>/dev/null | grep -q "Logs begin"; then
        journalctl -u mysql --since "2 hours ago" -n 20 2>/dev/null | tee -a "$LOGFILE"
    else
        log "Cannot access database journal logs"
    fi
    log ""

    log "Kernel OOM messages:"
    dmesg | grep -i "oom-kill\|out of memory" | tail -10 | tee -a "$LOGFILE" || log "No OOM messages found"
    log ""
}

analyze_network() {
    log_section "9. NETWORK STATISTICS"

    local established=$(netstat -an 2>/dev/null | grep ESTABLISHED | wc -l)
    local time_wait=$(netstat -an 2>/dev/null | grep TIME_WAIT | wc -l)
    local close_wait=$(netstat -an 2>/dev/null | grep CLOSE_WAIT | wc -l)

    log "ESTABLISHED connections: $established"
    log "TIME_WAIT connections: $time_wait"
    log "CLOSE_WAIT connections: $close_wait"
    log ""
}

analyze_disk_space() {
    log_section "10. DISK SPACE"

    df -h | tee -a "$LOGFILE"
    log ""
}

generate_summary() {
    log_section "SUMMARY AND RECOMMENDATIONS"

    # Memory usage alert
    local memory_usage=$(free | grep Mem | awk '{printf("%.0f", ($3/$2)*100)}')
    if [[ $memory_usage -gt $MEMORY_THRESHOLD ]]; then
        log_warning "Memory usage > ${MEMORY_THRESHOLD}% (${memory_usage}%)"
    fi

    # Disk usage alert
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -gt $DISK_THRESHOLD ]]; then
        log_warning "Disk usage > ${DISK_THRESHOLD}% (${disk_usage}%)"
    fi

    log ""
    log "Recommendations:"
    log "1. If lsphp processes > ${LONG_PROCESS_THRESHOLD}s: Review slow PHP code or N+1 queries"
    log "2. If max_connections near limit: Increase in MySQL/MariaDB configuration"
    log "3. Review slow query log to optimize indexes"
    log "4. If low memory: Consider increasing innodb_buffer_pool_size"
    log "5. Review query cache settings in RunCloud"
    log "6. Monitor OOM killer messages - may need to upgrade server resources"
    log ""
}

################################################################################
# Main Execution
################################################################################

main() {
    check_root
    create_log_dir

    log "========== SERVER ANALYSIS: RUNCLOUD + OPENLITESPEED + MYSQL/MARIADB =========="
    log "Script Version: $SCRIPT_VERSION"
    log "Timestamp: $TIMESTAMP"
    log ""

    analyze_system_resources
    analyze_openlitespeed
    analyze_lsphp_cpu
    analyze_long_running_php
    analyze_database
    analyze_slow_queries
    analyze_openlitespeed_logs
    analyze_system_logs
    analyze_network
    analyze_disk_space
    generate_summary

    log_success "Analysis completed. Log saved to: $LOGFILE"
    log ""
}

# Run main function
main "$@"
