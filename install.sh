#!/bin/bash

################################################################################
# Installation Script for Server Analysis Tool
# Author: David Carrero (https://carrero.es)
# Description: Automated installation of server analysis script
################################################################################

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Configuration
readonly INSTALL_PATH="/usr/local/bin/server-analysis"
readonly LOG_DIR="/home/logs"

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
}

log_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This installer must be run as root (use sudo)"
        exit 1
    fi
}

check_dependencies() {
    log_info "Checking dependencies..."

    local missing_deps=()

    # Check for MySQL/MariaDB client
    if ! command -v mariadb &> /dev/null && ! command -v mysql &> /dev/null; then
        # Detect which database server is installed to install matching client
        if systemctl list-units --type=service --all | grep -q "mariadb.service"; then
            missing_deps+=("mariadb-client")
        elif systemctl list-units --type=service --all | grep -q "mysql.service"; then
            missing_deps+=("mysql-client")
        else
            # Default to mariadb-client if no service found (RunCloud typically uses MariaDB)
            log_info "No database service detected, defaulting to mariadb-client"
            missing_deps+=("mariadb-client")
        fi
    fi

    if ! command -v netstat &> /dev/null; then
        missing_deps+=("net-tools")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_info "Installing missing dependencies: ${missing_deps[*]}"
        apt-get update
        apt-get install -y "${missing_deps[@]}"
        log_success "Dependencies installed"
    else
        log_success "All dependencies present"
    fi
}

install_script() {
    log_info "Installing server analysis script..."

    if [[ ! -f "server_analysis.sh" ]]; then
        log_error "server_analysis.sh not found in current directory"
        exit 1
    fi

    cp server_analysis.sh "$INSTALL_PATH"
    chmod +x "$INSTALL_PATH"

    log_success "Script installed to $INSTALL_PATH"
}

create_log_directory() {
    log_info "Creating log directory..."

    mkdir -p "$LOG_DIR"
    chmod 755 "$LOG_DIR"

    log_success "Log directory created at $LOG_DIR"
}

setup_cron() {
    log_info "Do you want to set up automatic monitoring via cron? (y/n)"
    read -r response

    # Sanitize input to only Y/y/N/n
    response="${response//[^YyNn]/}"

    if [[ -z "$response" ]]; then
        log_info "Invalid input, skipping cron setup"
        return 0
    fi

    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo ""
        echo "Select monitoring frequency:"
        echo "1) Every hour"
        echo "2) Every 4 hours"
        echo "3) Daily at 3 AM"
        echo "4) Custom (manual setup)"
        read -r freq_choice

        # Sanitize input to only digits 1-4
        freq_choice="${freq_choice//[^1-4]/}"

        if [[ -z "$freq_choice" ]]; then
            log_error "Invalid choice, skipping cron setup"
            return 1
        fi

        local cron_entry=""
        case $freq_choice in
            1)
                cron_entry="0 * * * * $INSTALL_PATH > /dev/null 2>&1"
                ;;
            2)
                cron_entry="0 */4 * * * $INSTALL_PATH > /dev/null 2>&1"
                ;;
            3)
                cron_entry="0 3 * * * $INSTALL_PATH > /dev/null 2>&1"
                ;;
            4)
                log_info "Run 'sudo crontab -e' to set up manually"
                log_info "Example: 0 * * * * $INSTALL_PATH > /dev/null 2>&1"
                return
                ;;
            *)
                log_error "Invalid choice"
                return
                ;;
        esac

        # Add to crontab
        (crontab -l 2>/dev/null | grep -v "$INSTALL_PATH"; echo "$cron_entry") | crontab -
        log_success "Cron job added: $cron_entry"
    fi
}

main() {
    echo "=========================================="
    echo "Server Analysis Tool - Installer"
    echo "=========================================="
    echo ""

    check_root
    check_dependencies
    install_script
    create_log_directory
    setup_cron

    echo ""
    log_success "Installation complete!"
    echo ""
    echo "Usage:"
    echo "  sudo server-analysis"
    echo ""
    echo "Logs will be saved to: $LOG_DIR"
    echo ""
}

main "$@"
