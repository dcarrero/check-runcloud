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
readonly SCRIPT_VERSION="3.0.0"
readonly TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
readonly LOG_DIR="/home/logs"
LOGFILE="${LOG_DIR}/server_analysis_$(date +%Y%m%d_%H%M%S).log"

# Global settings
ENABLE_LOGGING=true
INTERACTIVE_MODE=true

# Web server detection
WEB_SERVER=""  # Will be set to "openlitespeed" or "nginx"

# Language settings
# Detect system language (default to English)
SYSTEM_LANG=$(locale | grep LANG= | cut -d= -f2 | cut -d_ -f1)
if [[ "$SYSTEM_LANG" == "es" ]]; then
    LANG_CODE="es"
else
    LANG_CODE="en"
fi

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
# Internationalization (i18n)
################################################################################

# Translation function
t() {
    local key="$1"

    # English translations
    declare -A en=(
        # Menu
        ["menu_title"]="SERVER ANALYSIS TOOL"
        ["menu_select"]="Select checks to run:"
        ["menu_run_all"]="Run ALL checks"
        ["menu_options"]="Options:"
        ["menu_toggle_log"]="Toggle Logging [Current:"
        ["menu_toggle_lang"]="Change Language [Current:"
        ["menu_quit"]="Quit"
        ["menu_prompt"]="Enter your choice(s) (comma-separated or space-separated):"
        ["menu_press_enter"]="Press Enter to continue..."
        ["menu_exiting"]="Exiting..."

        # Check names
        ["check_1"]="System Resources (CPU, Memory, Swap)"
        ["check_2"]="Web Server Processes"
        ["check_3"]="PHP CPU Usage (Top 15)"
        ["check_4"]="Long-Running PHP Processes"
        ["check_5"]="MySQL/MariaDB Analysis"
        ["check_6"]="Slow Query Log"
        ["check_7"]="Web Server Logs"
        ["check_8"]="System Logs"
        ["check_9"]="Network Statistics"
        ["check_10"]="Disk Space"

        # Common
        ["on"]="ON"
        ["off"]="OFF"
        ["english"]="English"
        ["spanish"]="Spanish"
        ["enabled"]="ENABLED"
        ["disabled"]="DISABLED"
        ["logging"]="Logging:"
        ["script_version"]="Script Version:"
        ["timestamp"]="Timestamp:"
        ["recommendations"]="Recommendations:"
        ["error"]="ERROR:"
        ["warning"]="WARNING:"
        ["success"]="✓"

        # Help
        ["help_usage"]="Usage:"
        ["help_options"]="OPTIONS:"
        ["help_examples"]="EXAMPLES:"
        ["help_interactive"]="Interactive menu (default)"
        ["help_all_no_log"]="Run all checks without logging"
        ["help_specific"]="Run specific checks only"
        ["help_all_with_log"]="Run all checks with logging"
    )

    # Spanish translations
    declare -A es=(
        # Menu
        ["menu_title"]="HERRAMIENTA DE ANÁLISIS DEL SERVIDOR"
        ["menu_select"]="Seleccione las comprobaciones a ejecutar:"
        ["menu_run_all"]="Ejecutar TODAS las comprobaciones"
        ["menu_options"]="Opciones:"
        ["menu_toggle_log"]="Alternar Registro [Actual:"
        ["menu_toggle_lang"]="Cambiar Idioma [Actual:"
        ["menu_quit"]="Salir"
        ["menu_prompt"]="Ingrese su(s) opción(es) (separadas por comas o espacios):"
        ["menu_press_enter"]="Presione Enter para continuar..."
        ["menu_exiting"]="Saliendo..."

        # Check names
        ["check_1"]="Recursos del Sistema (CPU, Memoria, Swap)"
        ["check_2"]="Procesos del Servidor Web"
        ["check_3"]="Uso de CPU por PHP (Top 15)"
        ["check_4"]="Procesos PHP de Larga Duración"
        ["check_5"]="Análisis de MySQL/MariaDB"
        ["check_6"]="Registro de Consultas Lentas"
        ["check_7"]="Registros del Servidor Web"
        ["check_8"]="Registros del Sistema"
        ["check_9"]="Estadísticas de Red"
        ["check_10"]="Espacio en Disco"

        # Common
        ["on"]="ACTIVADO"
        ["off"]="DESACTIVADO"
        ["english"]="Inglés"
        ["spanish"]="Español"
        ["enabled"]="ACTIVADO"
        ["disabled"]="DESACTIVADO"
        ["logging"]="Registro:"
        ["script_version"]="Versión del Script:"
        ["timestamp"]="Fecha y Hora:"
        ["recommendations"]="Recomendaciones:"
        ["error"]="ERROR:"
        ["warning"]="ADVERTENCIA:"
        ["success"]="✓"

        # Help
        ["help_usage"]="Uso:"
        ["help_options"]="OPCIONES:"
        ["help_examples"]="EJEMPLOS:"
        ["help_interactive"]="Menú interactivo (predeterminado)"
        ["help_all_no_log"]="Ejecutar todas las comprobaciones sin registro"
        ["help_specific"]="Ejecutar solo comprobaciones específicas"
        ["help_all_with_log"]="Ejecutar todas las comprobaciones con registro"
    )

    # Return translation based on current language
    if [[ "$LANG_CODE" == "es" ]]; then
        echo "${es[$key]}"
    else
        echo "${en[$key]}"
    fi
}

################################################################################
# Helper Functions
################################################################################

log() {
    if [[ "$ENABLE_LOGGING" == true ]]; then
        echo -e "$1" | tee -a "$LOGFILE"
    else
        echo -e "$1"
    fi
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
    if [[ "$ENABLE_LOGGING" == true ]]; then
        mkdir -p "$LOG_DIR"
    fi
}

detect_web_server() {
    # Check for OpenLiteSpeed
    if command -v /usr/local/lsws/bin/lswsctrl &> /dev/null || [[ -d "/usr/local/lsws" ]]; then
        WEB_SERVER="openlitespeed"
        return
    fi

    # Check for Nginx
    if command -v nginx &> /dev/null || systemctl list-units | grep -q nginx; then
        WEB_SERVER="nginx"
        return
    fi

    # Default to unknown
    WEB_SERVER="unknown"
}

show_help() {
    cat << EOF
Server Analysis Script for RunCloud (OpenLiteSpeed/Nginx + MySQL/MariaDB)
Version: $SCRIPT_VERSION
Author: David Carrero
GitHub: https://github.com/dcarrero/check-runcloud

Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -a, --all               Run all checks (non-interactive mode)
    --no-log                Disable log file creation
    -1                      Run System Resources check
    -2                      Run OpenLiteSpeed Processes check
    -3                      Run LSPHP CPU Usage check
    -4                      Run Long-Running PHP Processes check
    -5                      Run MySQL/MariaDB Analysis
    -6                      Run Slow Query Log check
    -7                      Run OpenLiteSpeed Logs check
    -8                      Run System Logs check
    -9                      Run Network Statistics check
    -10                     Run Disk Space check

EXAMPLES:
    # Interactive menu (default)
    sudo $0

    # Run all checks without logging
    sudo $0 --all --no-log

    # Run specific checks only
    sudo $0 -1 -5 -10

    # Run all checks with logging
    sudo $0 -a

EOF
    exit 0
}

show_menu() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $(t "menu_title") v$SCRIPT_VERSION${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Author: David Carrero${NC}"
    echo -e "${BLUE}  GitHub: https://github.com/dcarrero/check-runcloud${NC}"
    echo -e "${BLUE}========================================${NC}"

    # Show detected web server
    local server_name
    case "$WEB_SERVER" in
        openlitespeed)
            server_name="OpenLiteSpeed"
            ;;
        nginx)
            server_name="Nginx"
            ;;
        *)
            server_name="Unknown"
            ;;
    esac
    echo -e "${GREEN}  Web Server: ${server_name}${NC}"
    echo ""

    echo -e "${GREEN}$(t "menu_select")${NC}"
    echo ""
    echo "  1)  $(t "check_1")"
    echo "  2)  $(t "check_2") ($server_name)"
    echo "  3)  $(t "check_3")"
    echo "  4)  $(t "check_4")"
    echo "  5)  $(t "check_5")"
    echo "  6)  $(t "check_6")"
    echo "  7)  $(t "check_7") ($server_name)"
    echo "  8)  $(t "check_8")"
    echo "  9)  $(t "check_9")"
    echo "  10) $(t "check_10")"
    echo ""
    echo -e "${YELLOW}  0)  $(t "menu_run_all")${NC}"
    echo ""
    echo -e "${GREEN}$(t "menu_options")${NC}"

    local log_status=$([ "$ENABLE_LOGGING" == true ] && t "on" || t "off")
    local lang_name=$([ "$LANG_CODE" == "es" ] && t "spanish" || t "english")

    echo "  l)  $(t "menu_toggle_log") ${log_status}]"
    echo "  i)  $(t "menu_toggle_lang") ${lang_name}]"
    echo "  q)  $(t "menu_quit")"
    echo ""
}

get_user_choice() {
    local choice
    read -p "$(t "menu_prompt") " choice
    echo "$choice"
}

run_selected_checks() {
    local choices="$1"

    # Replace commas with spaces for easier parsing
    choices="${choices//,/ }"

    # Header
    log "========== SERVER ANALYSIS: RUNCLOUD + OPENLITESPEED + MYSQL/MARIADB =========="
    log "Script Version: $SCRIPT_VERSION"
    log "Timestamp: $TIMESTAMP"
    log "Logging: $([ "$ENABLE_LOGGING" == true ] && echo "ENABLED ($LOGFILE)" || echo "DISABLED")"
    log ""

    # Process each choice
    for choice in $choices; do
        case $choice in
            0)
                run_all_checks
                return
                ;;
            1)
                analyze_system_resources
                ;;
            2)
                analyze_webserver_processes
                ;;
            3)
                analyze_php_cpu
                ;;
            4)
                analyze_long_running_php
                ;;
            5)
                analyze_database
                ;;
            6)
                analyze_slow_queries
                ;;
            7)
                analyze_webserver_logs
                ;;
            8)
                analyze_system_logs
                ;;
            9)
                analyze_network
                ;;
            10)
                analyze_disk_space
                ;;
            *)
                log_warning "Invalid option: $choice"
                ;;
        esac
    done

    generate_summary

    if [[ "$ENABLE_LOGGING" == true ]]; then
        log_success "Analysis completed. Log saved to: $LOGFILE"
    else
        log_success "Analysis completed."
    fi
    log ""
}

run_all_checks() {
    analyze_system_resources
    analyze_webserver_processes
    analyze_php_cpu
    analyze_long_running_php
    analyze_database
    analyze_slow_queries
    analyze_webserver_logs
    analyze_system_logs
    analyze_network
    analyze_disk_space
}

parse_args() {
    local run_checks=false
    local checks_to_run=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                # Already handled in main()
                ;;
            -a|--all)
                run_checks=true
                checks_to_run="0"
                INTERACTIVE_MODE=false
                ;;
            --no-log)
                ENABLE_LOGGING=false
                ;;
            -1|-2|-3|-4|-5|-6|-7|-8|-9|-10)
                run_checks=true
                checks_to_run="$checks_to_run ${1#-}"
                INTERACTIVE_MODE=false
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use -h or --help for usage information"
                exit 1
                ;;
        esac
        shift
    done

    if [[ "$run_checks" == true ]]; then
        echo "$checks_to_run"
    else
        echo ""
    fi
}

################################################################################
# Analysis Functions
################################################################################

analyze_system_resources() {
    log_section "1. SYSTEM RESOURCES"

    log "CPU, Memory and Swap Usage:"
    if [[ "$ENABLE_LOGGING" == true ]]; then
        free -h | tee -a "$LOGFILE"
    else
        free -h
    fi
    log ""

    local load_avg=$(uptime | awk -F'load average:' '{ print $2 }')
    log "System Load Average: $load_avg"

    local cpu_cores=$(nproc)
    log "CPU Cores: $cpu_cores"
    log ""

    # Recommendations
    local memory_usage=$(free | grep Mem | awk '{printf("%.0f", ($3/$2)*100)}')
    local swap_usage=$(free | grep Swap | awk '{if ($2 > 0) printf("%.0f", ($3/$2)*100); else print "0"}')

    log "${BLUE}Recommendations:${NC}"
    if [[ $memory_usage -gt 85 ]]; then
        log_warning "  • Memory usage is ${memory_usage}% - Consider:"
        log "    - Reducing innodb_buffer_pool_size in MySQL/MariaDB"
        log "    - Increasing server RAM"
        log "    - Optimizing PHP memory_limit values"
    elif [[ $memory_usage -gt 70 ]]; then
        log "${YELLOW}  • Memory usage is ${memory_usage}% - Monitor closely${NC}"
    else
        log_success "  • Memory usage is healthy (${memory_usage}%)"
    fi

    if [[ $swap_usage -gt 10 ]]; then
        log_warning "  • Swap usage is ${swap_usage}% - This indicates memory pressure"
        log "    - Upgrade RAM to avoid performance degradation"
    fi

    # Check load average
    local load_1min=$(echo "$load_avg" | awk -F',' '{print $1}' | xargs)
    local load_high=$(echo "$load_1min > $cpu_cores" | bc -l 2>/dev/null || echo 0)
    if [[ "$load_high" == "1" ]]; then
        log_warning "  • Load average ($load_1min) exceeds CPU cores ($cpu_cores)"
        log "    - Check for CPU-intensive processes"
        log "    - Review MySQL slow queries"
        log "    - Consider upgrading CPU resources"
    else
        log_success "  • Load average is normal"
    fi
    log ""
}

analyze_webserver_processes() {
    if [[ "$WEB_SERVER" == "openlitespeed" ]]; then
        analyze_openlitespeed_processes
    elif [[ "$WEB_SERVER" == "nginx" ]]; then
        analyze_nginx_processes
    else
        log_section "2. WEB SERVER PROCESSES"
        log_warning "Unknown web server - skipping this check"
        log ""
    fi
}

analyze_openlitespeed_processes() {
    log_section "2. OPENLITESPEED PROCESSES"

    log "Main OpenLiteSpeed processes:"
    if [[ "$ENABLE_LOGGING" == true ]]; then
        ps aux | grep -E "openlitespeed|lsphp" | grep -v grep | tee -a "$LOGFILE" || log "No OpenLiteSpeed processes found"
    else
        ps aux | grep -E "openlitespeed|lsphp" | grep -v grep || log "No OpenLiteSpeed processes found"
    fi
    log ""

    local ols_count=$(ps aux | grep -E "openlitespeed" | grep -v grep | wc -l)
    local lsphp_count=$(ps aux | grep -E "lsphp" | grep -v grep | wc -l)

    log "${BLUE}Recommendations:${NC}"
    if [[ $lsphp_count -gt 50 ]]; then
        log_warning "  • High number of LSPHP processes ($lsphp_count)"
        log "    - Review max connections in RunCloud"
        log "    - Check for stuck processes"
    else
        log_success "  • LSPHP process count is normal ($lsphp_count)"
    fi
    log ""
}

analyze_nginx_processes() {
    log_section "2. NGINX PROCESSES"

    log "Main Nginx processes:"
    if [[ "$ENABLE_LOGGING" == true ]]; then
        ps aux | grep -E "nginx|php-fpm" | grep -v grep | tee -a "$LOGFILE" || log "No Nginx processes found"
    else
        ps aux | grep -E "nginx|php-fpm" | grep -v grep || log "No Nginx processes found"
    fi
    log ""

    local nginx_count=$(ps aux | grep -E "nginx:" | grep -v grep | wc -l)
    local phpfpm_count=$(ps aux | grep -E "php-fpm" | grep -v grep | wc -l)

    log "${BLUE}Recommendations:${NC}"
    if [[ $phpfpm_count -gt 50 ]]; then
        log_warning "  • High number of PHP-FPM processes ($phpfpm_count)"
        log "    - Review pm.max_children in PHP-FPM config"
        log "    - Check for stuck processes"
    else
        log_success "  • PHP-FPM process count is normal ($phpfpm_count)"
    fi
    log ""
}

analyze_php_cpu() {
    if [[ "$WEB_SERVER" == "openlitespeed" ]]; then
        analyze_lsphp_cpu
    elif [[ "$WEB_SERVER" == "nginx" ]]; then
        analyze_phpfpm_cpu
    else
        log_section "3. PHP CPU USAGE"
        log_warning "Unknown web server - skipping this check"
        log ""
    fi
}

analyze_lsphp_cpu() {
    log_section "3. TOP 15 LSPHP PROCESSES BY CPU USAGE"

    if [[ "$ENABLE_LOGGING" == true ]]; then
        ps aux --sort=-%cpu | grep lsphp | grep -v grep | head -15 | tee -a "$LOGFILE" || log "No LSPHP processes found"
    else
        ps aux --sort=-%cpu | grep lsphp | grep -v grep | head -15 || log "No LSPHP processes found"
    fi
    log ""

    local high_cpu_count=$(ps aux | grep lsphp | grep -v grep | awk '{if ($3 > 50) print $0}' | wc -l)

    log "${BLUE}Recommendations:${NC}"
    if [[ $high_cpu_count -gt 5 ]]; then
        log_warning "  • Multiple LSPHP processes with high CPU usage (${high_cpu_count} processes > 50%)"
        log "    - Enable PHP opcache in RunCloud"
        log "    - Profile PHP code to find bottlenecks"
        log "    - Check for infinite loops or heavy computations"
        log "    - Review database query performance"
    elif [[ $high_cpu_count -gt 0 ]]; then
        log "${YELLOW}  • Some LSPHP processes have high CPU (${high_cpu_count} processes > 50%)${NC}"
        log "    - Review which applications are causing high load"
    else
        log_success "  • CPU usage is normal"
    fi
    log ""
}

analyze_phpfpm_cpu() {
    log_section "3. TOP 15 PHP-FPM PROCESSES BY CPU USAGE"

    if [[ "$ENABLE_LOGGING" == true ]]; then
        ps aux --sort=-%cpu | grep php-fpm | grep -v grep | head -15 | tee -a "$LOGFILE" || log "No PHP-FPM processes found"
    else
        ps aux --sort=-%cpu | grep php-fpm | grep -v grep | head -15 || log "No PHP-FPM processes found"
    fi
    log ""

    local high_cpu_count=$(ps aux | grep php-fpm | grep -v grep | awk '{if ($3 > 50) print $0}' | wc -l)

    log "${BLUE}Recommendations:${NC}"
    if [[ $high_cpu_count -gt 5 ]]; then
        log_warning "  • Multiple PHP-FPM processes with high CPU usage (${high_cpu_count} processes > 50%)"
        log "    - Enable PHP opcache"
        log "    - Review pm.max_children and pm settings in PHP-FPM pools"
        log "    - Profile PHP code to find bottlenecks"
        log "    - Check for infinite loops or heavy computations"
        log "    - Review database query performance"
    elif [[ $high_cpu_count -gt 0 ]]; then
        log "${YELLOW}  • Some PHP-FPM processes have high CPU (${high_cpu_count} processes > 50%)${NC}"
        log "    - Review which applications are causing high load"
    else
        log_success "  • CPU usage is normal"
    fi
    log ""
}

analyze_long_running_php() {
    log_section "4. LSPHP PROCESSES RUNNING > ${LONG_PROCESS_THRESHOLD} SECONDS"

    local long_processes
    if [[ "$ENABLE_LOGGING" == true ]]; then
        long_processes=$(ps -eo pid,etime,vsz,rss,%cpu,%mem,cmd | grep lsphp | grep -v grep | awk -v threshold="$LONG_PROCESS_THRESHOLD" '
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
        ' | tee -a "$LOGFILE")
    else
        long_processes=$(ps -eo pid,etime,vsz,rss,%cpu,%mem,cmd | grep lsphp | grep -v grep | awk -v threshold="$LONG_PROCESS_THRESHOLD" '
            BEGIN {
                print "PID\t\tTIME\t\tVSZ\tRSS\t%CPU\t%MEM\tCOMMAND"
                found=0
            }
            {
                split($2, time, "-")
                show=0

                if (length(time) > 1) {
                    show=1
                } else {
                    split($2, hms, ":")
                    if (length(hms) == 3) {
                        if (hms[1] >= 1 || (hms[1] == 0 && hms[2] >= 1)) {
                            show=1
                        }
                    } else if (length(hms) == 2) {
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
        ')
        echo "$long_processes"
    fi
    log ""

    local long_count=$(echo "$long_processes" | grep -v "PID" | grep -v "No long-running" | wc -l)

    log "${BLUE}Recommendations:${NC}"
    if [[ $long_count -gt 5 ]]; then
        log_warning "  • Multiple long-running PHP processes detected ($long_count processes)"
        log "    - CRITICAL: Review slow database queries immediately"
        log "    - Check for N+1 query problems in ORM/frameworks"
        log "    - Consider killing stuck processes: kill -9 <PID>"
        log "    - Enable slow query log in MySQL/MariaDB"
        log "    - Review application code for infinite loops"
    elif [[ $long_count -gt 0 ]]; then
        log "${YELLOW}  • Some long-running PHP processes found ($long_count processes)${NC}"
        log "    - Review the processes to determine if they're legitimate"
        log "    - Check MySQL processlist for slow queries"
    else
        log_success "  • No long-running processes detected"
    fi
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
    if [[ "$ENABLE_LOGGING" == true ]]; then
        $mysql_client -S "$mysql_socket" --connect-timeout=10 -e "STATUS\G" 2>/dev/null | tee -a "$LOGFILE" || log_error "Cannot connect to database"
    else
        $mysql_client -S "$mysql_socket" --connect-timeout=10 -e "STATUS\G" 2>/dev/null || log_error "Cannot connect to database"
    fi
    log ""

    # Active Processes
    log "Active database processes (> 5 seconds):"
    local slow_queries
    if [[ "$ENABLE_LOGGING" == true ]]; then
        slow_queries=$($mysql_client -S "$mysql_socket" --connect-timeout=10 -e "
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
        \G" 2>/dev/null | tee -a "$LOGFILE" || log_error "Cannot query processlist")
    else
        slow_queries=$($mysql_client -S "$mysql_socket" --connect-timeout=10 -e "
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
        \G" 2>/dev/null || log_error "Cannot query processlist")
        echo "$slow_queries"
    fi
    log ""

    # Connections by User
    log "Active connections by user:"
    if [[ "$ENABLE_LOGGING" == true ]]; then
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
    else
        $mysql_client -S "$mysql_socket" --connect-timeout=10 -e "
        SELECT
            USER,
            COUNT(*) as CONNECTIONS,
            SUM(IF(TIME > 30, 1, 0)) as OVER_30S,
            MAX(TIME) as MAX_TIME
        FROM INFORMATION_SCHEMA.PROCESSLIST
        GROUP BY USER
        ORDER BY CONNECTIONS DESC
        \G" 2>/dev/null
    fi
    log ""

    # Critical Variables
    log "Critical InnoDB variables:"
    local db_vars
    if [[ "$ENABLE_LOGGING" == true ]]; then
        db_vars=$($mysql_client -S "$mysql_socket" --connect-timeout=10 -e "
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
        \G" 2>/dev/null | tee -a "$LOGFILE")
    else
        db_vars=$($mysql_client -S "$mysql_socket" --connect-timeout=10 -e "
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
        \G" 2>/dev/null)
        echo "$db_vars"
    fi
    log ""

    # InnoDB Status
    log "InnoDB Status (first 80 lines):"
    if [[ "$ENABLE_LOGGING" == true ]]; then
        $mysql_client -S "$mysql_socket" --connect-timeout=10 -e "SHOW ENGINE INNODB STATUS\G" 2>/dev/null | head -80 | tee -a "$LOGFILE"
    else
        $mysql_client -S "$mysql_socket" --connect-timeout=10 -e "SHOW ENGINE INNODB STATUS\G" 2>/dev/null | head -80
    fi
    log ""

    # Recommendations for database
    local slow_query_count=$(echo "$slow_queries" | grep "ID:" | wc -l)
    local max_connections=$(echo "$db_vars" | grep "max_connections" | awk '{print $2}')
    local current_connections=$($mysql_client -S "$mysql_socket" --connect-timeout=10 -e "SHOW STATUS LIKE 'Threads_connected';" 2>/dev/null | tail -1 | awk '{print $2}')

    log "${BLUE}Recommendations:${NC}"
    if [[ $slow_query_count -gt 10 ]]; then
        log_warning "  • High number of slow queries ($slow_query_count queries > 5s)"
        log "    - Review and optimize slow queries immediately"
        log "    - Add missing indexes"
        log "    - Consider query caching"
    elif [[ $slow_query_count -gt 0 ]]; then
        log "${YELLOW}  • Some slow queries detected ($slow_query_count queries > 5s)${NC}"
        log "    - Review query performance"
    else
        log_success "  • No slow queries detected"
    fi

    if [[ -n "$max_connections" && -n "$current_connections" ]]; then
        local conn_percentage=$(echo "scale=0; ($current_connections * 100) / $max_connections" | bc -l 2>/dev/null || echo 0)
        if [[ $conn_percentage -gt 80 ]]; then
            log_warning "  • Connection usage is ${conn_percentage}% ($current_connections / $max_connections)"
            log "    - Increase max_connections in MySQL/MariaDB config"
            log "    - Review connection pooling in applications"
        fi
    fi

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
        if [[ "$ENABLE_LOGGING" == true ]]; then
            tail -30 "$slow_log_path" 2>/dev/null | tee -a "$LOGFILE"
        else
            tail -30 "$slow_log_path" 2>/dev/null
        fi
    else
        log "Slow query log not found or not accessible"
    fi
    log ""

    log "${BLUE}Recommendations:${NC}"
    if [[ -f "$slow_log_path" ]]; then
        local slow_count=$(grep -c "Query_time" "$slow_log_path" 2>/dev/null || echo 0)
        if [[ $slow_count -gt 100 ]]; then
            log_warning "  • Many slow queries in log ($slow_count entries)"
            log "    - Use mysqldumpslow to analyze patterns"
            log "    - Add missing indexes on frequently queried columns"
            log "    - Consider query result caching"
        elif [[ $slow_count -gt 0 ]]; then
            log "${YELLOW}  • Some slow queries logged ($slow_count entries)${NC}"
            log "    - Review and optimize queries"
        else
            log_success "  • No slow queries logged recently"
        fi
    fi
    log ""
}

analyze_webserver_logs() {
    if [[ "$WEB_SERVER" == "openlitespeed" ]]; then
        analyze_openlitespeed_logs
    elif [[ "$WEB_SERVER" == "nginx" ]]; then
        analyze_nginx_logs
    else
        log_section "7. WEB SERVER LOGS"
        log_warning "Unknown web server - skipping this check"
        log ""
    fi
}

analyze_openlitespeed_logs() {
    log_section "7. OPENLITESPEED LOGS"

    local ols_error_log="/usr/local/lsws/logs/error.log"
    local ols_access_log="/usr/local/lsws/logs/access.log"

    if [[ -f "$ols_error_log" ]]; then
        log "Last 20 OpenLiteSpeed errors:"
        if [[ "$ENABLE_LOGGING" == true ]]; then
            tail -20 "$ols_error_log" | tee -a "$LOGFILE"
        else
            tail -20 "$ols_error_log"
        fi
    else
        log "OpenLiteSpeed error log not found at $ols_error_log"
    fi
    log ""

    log "${BLUE}Recommendations:${NC}"
    if [[ -f "$ols_error_log" ]]; then
        local error_count=$(tail -100 "$ols_error_log" 2>/dev/null | wc -l)
        local critical_errors=$(tail -100 "$ols_error_log" 2>/dev/null | grep -i "error\|critical\|fatal" | wc -l)

        if [[ $critical_errors -gt 20 ]]; then
            log_warning "  • Many critical errors in OpenLiteSpeed log ($critical_errors in last 100 lines)"
            log "    - Review error log for recurring issues"
            log "    - Check PHP error logs for application errors"
        elif [[ $critical_errors -gt 0 ]]; then
            log "${YELLOW}  • Some errors in OpenLiteSpeed log ($critical_errors in last 100 lines)${NC}"
        else
            log_success "  • No critical errors in recent logs"
        fi
    fi
    log ""
}

analyze_nginx_logs() {
    log_section "7. NGINX LOGS"

    local nginx_error_log="/var/log/nginx/error.log"
    local nginx_access_log="/var/log/nginx/access.log"

    if [[ -f "$nginx_error_log" ]]; then
        log "Last 20 Nginx errors:"
        if [[ "$ENABLE_LOGGING" == true ]]; then
            tail -20 "$nginx_error_log" | tee -a "$LOGFILE"
        else
            tail -20 "$nginx_error_log"
        fi
    else
        log "Nginx error log not found at $nginx_error_log"
    fi
    log ""

    log "${BLUE}Recommendations:${NC}"
    if [[ -f "$nginx_error_log" ]]; then
        local error_count=$(tail -100 "$nginx_error_log" 2>/dev/null | wc -l)
        local critical_errors=$(tail -100 "$nginx_error_log" 2>/dev/null | grep -i "error\|critical\|fatal\|emerg" | wc -l)

        if [[ $critical_errors -gt 20 ]]; then
            log_warning "  • Many critical errors in Nginx log ($critical_errors in last 100 lines)"
            log "    - Review error log for recurring issues"
            log "    - Check PHP-FPM error logs for application errors"
            log "    - Review upstream connection issues"
        elif [[ $critical_errors -gt 0 ]]; then
            log "${YELLOW}  • Some errors in Nginx log ($critical_errors in last 100 lines)${NC}"
        else
            log_success "  • No critical errors in recent logs"
        fi
    fi
    log ""
}

analyze_system_logs() {
    log_section "8. RECENT SYSTEM LOGS"

    log "Database logs (last 2 hours):"
    # Try MariaDB first, then MySQL
    if [[ "$ENABLE_LOGGING" == true ]]; then
        if journalctl -u mariadb --since "2 hours ago" -n 1 2>/dev/null | grep -q "Logs begin"; then
            journalctl -u mariadb --since "2 hours ago" -n 20 2>/dev/null | tee -a "$LOGFILE"
        elif journalctl -u mysql --since "2 hours ago" -n 1 2>/dev/null | grep -q "Logs begin"; then
            journalctl -u mysql --since "2 hours ago" -n 20 2>/dev/null | tee -a "$LOGFILE"
        else
            log "Cannot access database journal logs"
        fi
    else
        if journalctl -u mariadb --since "2 hours ago" -n 1 2>/dev/null | grep -q "Logs begin"; then
            journalctl -u mariadb --since "2 hours ago" -n 20 2>/dev/null
        elif journalctl -u mysql --since "2 hours ago" -n 1 2>/dev/null | grep -q "Logs begin"; then
            journalctl -u mysql --since "2 hours ago" -n 20 2>/dev/null
        else
            log "Cannot access database journal logs"
        fi
    fi
    log ""

    log "Kernel OOM messages:"
    local oom_output
    if [[ "$ENABLE_LOGGING" == true ]]; then
        oom_output=$(dmesg | grep -i "oom-kill\|out of memory" | tail -10 | tee -a "$LOGFILE" || log "No OOM messages found")
    else
        oom_output=$(dmesg | grep -i "oom-kill\|out of memory" | tail -10 || echo "No OOM messages found")
        echo "$oom_output"
    fi
    log ""

    log "${BLUE}Recommendations:${NC}"
    local oom_count=$(echo "$oom_output" | grep -i "oom-kill\|out of memory" | wc -l)
    if [[ $oom_count -gt 0 ]]; then
        log_warning "  • OOM Killer has been triggered ($oom_count recent events)"
        log "    - CRITICAL: Server is running out of memory"
        log "    - Increase server RAM immediately"
        log "    - Reduce innodb_buffer_pool_size"
        log "    - Review and optimize memory-hungry processes"
    else
        log_success "  • No OOM events detected"
    fi
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

    # Recommendations for network
    log "${BLUE}Recommendations:${NC}"
    if [[ $close_wait -gt 100 ]]; then
        log_warning "  • High CLOSE_WAIT connections ($close_wait)"
        log "    - This indicates application not properly closing connections"
        log "    - Review application code for connection handling"
        log "    - Check for resource leaks in PHP code"
    fi

    if [[ $time_wait -gt 5000 ]]; then
        log_warning "  • Very high TIME_WAIT connections ($time_wait)"
        log "    - This is usually normal under high traffic"
        log "    - Consider tuning TCP settings if persistent"
    fi

    if [[ $established -gt 1000 ]]; then
        log "${YELLOW}  • High ESTABLISHED connections ($established)${NC}"
        log "    - Monitor for potential DDoS or traffic spike"
    else
        log_success "  • Network connection counts are normal"
    fi
    log ""
}

analyze_disk_space() {
    log_section "10. DISK SPACE"

    if [[ "$ENABLE_LOGGING" == true ]]; then
        df -h | tee -a "$LOGFILE"
    else
        df -h
    fi
    log ""

    # Recommendations for disk space
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

    log "${BLUE}Recommendations:${NC}"
    if [[ $disk_usage -gt 90 ]]; then
        log_warning "  • CRITICAL: Disk usage is ${disk_usage}%"
        log "    - Clean up old logs: find /var/log -type f -name '*.log' -mtime +30 -delete"
        log "    - Remove old backups"
        log "    - Clean package cache: apt-get clean"
        log "    - Check for large files: du -sh /* | sort -rh | head -10"
    elif [[ $disk_usage -gt 80 ]]; then
        log_warning "  • Disk usage is ${disk_usage}% - Take action soon"
        log "    - Review and clean old log files"
        log "    - Check for unnecessary backups"
    else
        log_success "  • Disk usage is healthy (${disk_usage}%)"
    fi
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
    # Handle --help before checking root
    for arg in "$@"; do
        if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
            show_help
        fi
    done

    # Check root
    check_root

    # Detect web server
    detect_web_server

    # Parse command line arguments
    local checks_to_run
    checks_to_run=$(parse_args "$@")

    create_log_dir

    # Non-interactive mode (command-line arguments provided)
    if [[ "$INTERACTIVE_MODE" == false ]]; then
        run_selected_checks "$checks_to_run"
        return
    fi

    # Interactive mode
    while true; do
        show_menu
        local choice
        choice=$(get_user_choice)

        case $choice in
            q|Q)
                echo "$(t "menu_exiting")"
                exit 0
                ;;
            l|L)
                if [[ "$ENABLE_LOGGING" == true ]]; then
                    ENABLE_LOGGING=false
                else
                    ENABLE_LOGGING=true
                    create_log_dir
                    # Regenerate logfile name
                    LOGFILE="${LOG_DIR}/server_analysis_$(date +%Y%m%d_%H%M%S).log"
                fi
                ;;
            i|I)
                # Toggle language
                if [[ "$LANG_CODE" == "es" ]]; then
                    LANG_CODE="en"
                else
                    LANG_CODE="es"
                fi
                ;;
            *)
                run_selected_checks "$choice"
                echo ""
                read -p "$(t "menu_press_enter")"
                ;;
        esac
    done
}

# Run main function
main "$@"
