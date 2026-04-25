#!/bin/bash

# Kodakclout User Management CLI
# Use this script to quickly update user balances or check player stats via terminal.

DB_USER="clout_user"
DB_PASS="clout_pass"
DB_NAME="kodakclout"

log() { echo -e "\e[34m[INFO]\e[0m $1"; }
success() { echo -e "\e[32m[SUCCESS]\e[0m $1"; }
error() { echo -e "\e[31m[ERROR]\e[0m $1"; exit 1; }

usage() {
    echo "Usage: $0 [command] [args]"
    echo ""
    echo "Commands:"
    echo "  list                List all players and their balances"
    echo "  balance [id] [amt]  Set a specific user's balance"
    echo "  stats               Show platform-wide player stats"
    echo ""
    exit 1
}

case "$1" in
    list)
        log "Fetching player list..."
        mysql -u${DB_USER} -p${DB_PASS} ${DB_NAME} -e "SELECT id, name, email, balance, created_at FROM users;"
        ;;
    balance)
        if [ -z "$2" ] || [ -z "$3" ]; then usage; fi
        log "Updating User ID $2 balance to \$$3..."
        mysql -u${DB_USER} -p${DB_PASS} ${DB_NAME} -e "UPDATE users SET balance = $3 WHERE id = $2;"
        success "Balance updated successfully."
        ;;
    stats)
        log "Platform Stats:"
        mysql -u${DB_USER} -p${DB_PASS} ${DB_NAME} -e "SELECT COUNT(*) as total_players, SUM(balance) as total_liabilities FROM users;"
        ;;
    *)
        usage
        ;;
esac
