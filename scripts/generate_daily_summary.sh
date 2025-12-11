#!/bin/bash

# Bitcoin Price Tracker Daily Summary Generator
# COMP1314 Data Management Coursework

# Configuration
DB_NAME="bitcoin_tracker"
DB_USER="root"
MYSQL_PATH="/usr/bin/mysql"
LOG_FILE="/mnt/c/Users/24476/cw2/logs/daily_summary.log"

# Logging function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to generate daily summary
generate_summary() {
    local target_date="${1:-$(date '+%Y-%m-%d')}"
    log_message "Generating daily summary for $target_date"
    
    # SQL query to calculate daily summary
    local sql_query="
        USE $DB_NAME;
        
        INSERT INTO daily_summaries 
        (date, opening_price, closing_price, highest_price, lowest_price, average_price, total_volume, price_change, price_change_percent)
        SELECT 
            DATE(timestamp) as date,
            (SELECT price_usd FROM bitcoin_prices WHERE DATE(timestamp) = '$target_date' ORDER BY timestamp ASC LIMIT 1) as opening_price,
            (SELECT price_usd FROM bitcoin_prices WHERE DATE(timestamp) = '$target_date' ORDER BY timestamp DESC LIMIT 1) as closing_price,
            MAX(price_usd) as highest_price,
            MIN(price_usd) as lowest_price,
            AVG(price_usd) as average_price,
            COALESCE(SUM(volume_24h), 0) as total_volume,
            (SELECT price_usd FROM bitcoin_prices WHERE DATE(timestamp) = '$target_date' ORDER BY timestamp DESC LIMIT 1) - 
            (SELECT price_usd FROM bitcoin_prices WHERE DATE(timestamp) = '$target_date' ORDER BY timestamp ASC LIMIT 1) as price_change,
            ROUND(
                (((SELECT price_usd FROM bitcoin_prices WHERE DATE(timestamp) = '$target_date' ORDER BY timestamp DESC LIMIT 1) - 
                  (SELECT price_usd FROM bitcoin_prices WHERE DATE(timestamp) = '$target_date' ORDER BY timestamp ASC LIMIT 1)) / 
                 (SELECT price_usd FROM bitcoin_prices WHERE DATE(timestamp) = '$target_date' ORDER BY timestamp ASC LIMIT 1)) * 100, 4
            ) as price_change_percent
        FROM bitcoin_prices 
        WHERE DATE(timestamp) = '$target_date'
        GROUP BY DATE(timestamp)
        ON DUPLICATE KEY UPDATE
            opening_price = VALUES(opening_price),
            closing_price = VALUES(closing_price),
            highest_price = VALUES(highest_price),
            lowest_price = VALUES(lowest_price),
            average_price = VALUES(average_price),
            total_volume = VALUES(total_volume),
            price_change = VALUES(price_change),
            price_change_percent = VALUES(price_change_percent);
    "
    
    # Execute query
    $MYSQL_PATH -u $DB_USER -e "$sql_query" 2>> "$LOG_FILE"
    
    if [ $? -eq 0 ]; then
        log_message "Daily summary generated successfully for $target_date"
        
        # Display summary
        display_summary "$target_date"
    else
        log_message "Failed to generate daily summary for $target_date"
        return 1
    fi
}

# Function to display daily summary
display_summary() {
    local target_date="$1"
    log_message "Daily Summary for $target_date:"
    
    local result=$($MYSQL_PATH -u $DB_USER -e "
        USE $DB_NAME;
        SELECT 
            date,
            opening_price,
            closing_price,
            highest_price,
            lowest_price,
            average_price,
            price_change,
            price_change_percent
        FROM daily_summaries 
        WHERE date = '$target_date';
    " --batch --raw 2>> "$LOG_FILE")
    
    echo "$result" | tee -a "$LOG_FILE"
}

# Function to generate weekly summary
generate_weekly_summary() {
    local start_date="${1:-$(date -d '7 days ago' '+%Y-%m-%d')}"
    local end_date="${2:-$(date '+%Y-%m-%d')}"
    
    log_message "Generating weekly summary from $start_date to $end_date"
    
    local result=$($MYSQL_PATH -u $DB_USER -e "
        USE $DB_NAME;
        SELECT 
            date,
            opening_price,
            closing_price,
            highest_price,
            lowest_price,
            price_change_percent
        FROM daily_summaries 
        WHERE date BETWEEN '$start_date' AND '$end_date'
        ORDER BY date;
    " --batch --raw 2>> "$LOG_FILE")
    
    echo "Weekly Summary ($start_date to $end_date):"
    echo "$result" | tee -a "$LOG_FILE"
}

# Function to check for price alerts
check_price_alerts() {
    log_message "Checking price alerts..."
    
    # Get current price
    local current_price=$($MYSQL_PATH -u $DB_USER -e "
        USE $DB_NAME;
        SELECT price_usd FROM bitcoin_prices ORDER BY timestamp DESC LIMIT 1;
    " --batch --raw --skip-column-names 2>> "$LOG_FILE")
    
    if [ -n "$current_price" ]; then
        # Check for alerts that should be triggered
        local alerts=$($MYSQL_PATH -u $DB_USER -e "
            USE $DB_NAME;
            SELECT id, alert_type, target_price FROM price_alerts 
            WHERE is_active = TRUE AND (
                (alert_type = 'ABOVE' AND target_price <= $current_price) OR
                (alert_type = 'BELOW' AND target_price >= $current_price)
            );
        " --batch --raw 2>> "$LOG_FILE")
        
        if [ -n "$alerts" ]; then
            log_message "Price alerts triggered! Current price: $current_price"
            echo "$alerts" | while read line; do
                log_message "Alert: $line"
            done
        fi
    fi
}

# Main execution
main() {
    local action="${1:-daily}"
    local date_param="$2"
    
    case "$action" in
        "daily")
            generate_summary "$date_param"
            ;;
        "weekly")
            generate_weekly_summary "$date_param"
            ;;
        "alerts")
            check_price_alerts
            ;;
        "all")
            generate_summary "$date_param"
            check_price_alerts
            ;;
        *)
            echo "Usage: $0 {daily|weekly|alerts|all} [date]"
            echo "  daily  - Generate daily summary (default)"
            echo "  weekly - Generate weekly summary"
            echo "  alerts - Check price alerts"
            echo "  all    - Generate summary and check alerts"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"