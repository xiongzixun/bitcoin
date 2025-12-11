#!/bin/bash

# Bitcoin Price Tracker Crontab Setup Script
# COMP1314 Data Management Coursework

# Configuration
SCRIPT_DIR="/mnt/c/Users/24476/cw2/scripts"
COLLECT_SCRIPT="$SCRIPT_DIR/collect_data.sh"
LOG_DIR="/mnt/c/Users/24476/cw2/logs"

# Create log directory
mkdir -p "$LOG_DIR"

# Function to setup crontab
setup_crontab() {
    echo "Setting up crontab for Bitcoin price tracking..."
    
    # Create temporary crontab file
    TEMP_CRON=$(mktemp)
    
    # Get existing crontab entries
    crontab -l > "$TEMP_CRON" 2>/dev/null || echo "# Bitcoin Price Tracker Crontab" > "$TEMP_CRON"
    
    # Check if our entry already exists
    if grep -q "collect_data.sh" "$TEMP_CRON"; then
        echo "Crontab entry already exists. Removing old entry..."
        grep -v "collect_data.sh" "$TEMP_CRON" > "${TEMP_CRON}.new"
        mv "${TEMP_CRON}.new" "$TEMP_CRON"
    fi
    
    # Add new crontab entries
    echo "" >> "$TEMP_CRON"
    echo "# Bitcoin Price Tracker - Data Collection" >> "$TEMP_CRON"
    echo "# Collect data every hour" >> "$TEMP_CRON"
    echo "0 * * * * $COLLECT_SCRIPT >> $LOG_DIR/cron.log 2>&1" >> "$TEMP_CRON"
    echo "" >> "$TEMP_CRON"
    echo "# Bitcoin Price Tracker - Daily Summary" >> "$TEMP_CRON"
    echo "# Generate daily summary at 23:55" >> "$TEMP_CRON"
    echo "55 23 * * * $SCRIPT_DIR/generate_daily_summary.sh >> $LOG_DIR/cron.log 2>&1" >> "$TEMP_CRON"
    echo "" >> "$TEMP_CRON"
    echo "# Bitcoin Price Tracker - Weekly Cleanup" >> "$TEMP_CRON"
    echo "# Clean old logs every Sunday at 02:00" >> "$TEMP_CRON"
    echo "0 2 * * 0 find $LOG_DIR -name '*.log' -mtime +30 -delete" >> "$TEMP_CRON"
    
    # Install new crontab
    crontab "$TEMP_CRON"
    
    if [ $? -eq 0 ]; then
        echo "Crontab setup completed successfully!"
        echo ""
        echo "Current crontab entries:"
        crontab -l | grep -E "(Bitcoin|collect_data|generate_daily_summary)"
        echo ""
        echo "Logs will be saved to: $LOG_DIR/cron.log"
    else
        echo "Failed to setup crontab"
        exit 1
    fi
    
    # Clean up temporary file
    rm -f "$TEMP_CRON"
}

# Function to test crontab setup
test_crontab() {
    echo "Testing crontab setup..."
    
    # Check if crontab service is running
    if ! systemctl is-active --quiet cron 2>/dev/null; then
        echo "Warning: Cron service may not be running"
        echo "Try: sudo systemctl start cron"
    fi
    
    # Test script execution
    echo "Running script manually to test..."
    if "$COLLECT_SCRIPT"; then
        echo "Script executed successfully!"
    else
        echo "Script execution failed. Check configuration."
        exit 1
    fi
}

# Function to show current setup
show_setup() {
    echo "Current crontab setup:"
    echo "====================="
    crontab -l | grep -E "(Bitcoin|collect_data|generate_daily_summary)" || echo "No Bitcoin tracker entries found"
    echo ""
    echo "Next scheduled runs:"
    echo "===================="
    # Show next few scheduled runs (simplified)
    echo "Data collection: Every hour at minute 0"
    echo "Daily summary: Daily at 23:55"
    echo "Log cleanup: Weekly on Sunday at 02:00"
}

# Function to remove crontab entries
remove_crontab() {
    echo "Removing Bitcoin tracker crontab entries..."
    
    TEMP_CRON=$(mktemp)
    crontab -l > "$TEMP_CRON" 2>/dev/null || echo "# Empty crontab" > "$TEMP_CRON"
    
    # Remove Bitcoin tracker entries
    grep -v -E "(Bitcoin|collect_data|generate_daily_summary)" "$TEMP_CRON" > "${TEMP_CRON}.new"
    mv "${TEMP_CRON}.new" "$TEMP_CRON"
    
    # Install updated crontab
    crontab "$TEMP_CRON"
    
    if [ $? -eq 0 ]; then
        echo "Crontab entries removed successfully!"
    else
        echo "Failed to remove crontab entries"
        exit 1
    fi
    
    rm -f "$TEMP_CRON"
}

# Main menu
case "${1:-setup}" in
    "setup")
        setup_crontab
        test_crontab
        ;;
    "test")
        test_crontab
        ;;
    "show")
        show_setup
        ;;
    "remove")
        remove_crontab
        ;;
    *)
        echo "Usage: $0 {setup|test|show|remove}"
        echo "  setup  - Install crontab entries (default)"
        echo "  test   - Test script execution"
        echo "  show   - Show current crontab setup"
        echo "  remove - Remove crontab entries"
        exit 1
        ;;
esac