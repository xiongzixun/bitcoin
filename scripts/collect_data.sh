#!/bin/bash

# Bitcoin Price Tracker Data Collection Script
# COMP1314 Data Management Coursework

# Configuration
DB_NAME="bitcoin_tracker"
DB_USER="root"
MYSQL_PATH="/usr/bin/mysql"
LOG_FILE="bitcoin_tracker.log"
DATA_DIR="/mnt/c/Users/24476/cw2/data"

# Create data directory if it doesn't exist
mkdir -p "$DATA_DIR"

# Logging function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$DATA_DIR/$LOG_FILE"
}

# Error handling function
handle_error() {
    local error_message="$1"
    log_message "ERROR: $error_message"
    exit 1
}

# Function to check network connectivity
check_network() {
    if ! ping -c 1 google.com &> /dev/null; then
        handle_error "Network connection is down"
    fi
}

# Function to fetch data from CoinMarketCap
fetch_coinmarketcap_data() {
    log_message "Fetching data from CoinMarketCap..."
    
    # Use curl with proper headers to avoid blocking
    local response=$(curl -s -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
                          -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
                          "https://coinmarketcap.com/currencies/bitcoin/" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        handle_error "Failed to fetch data from CoinMarketCap"
    fi
    
    echo "$response" > "$DATA_DIR/coinmarketcap_raw.html"
    log_message "CoinMarketCap data saved to raw HTML"
}

# Function to parse Bitcoin price data
parse_bitcoin_data() {
    log_message "Parsing Bitcoin price data..."
    
    local html_file="$DATA_DIR/coinmarketcap_raw.html"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Extract price using various selectors (fallback approach)
    local price=$(grep -o '"price":"[^"]*"' "$html_file" | head -1 | cut -d'"' -f4)
    
    # If price extraction fails, try alternative method
    if [ -z "$price" ]; then
        price=$(grep -o '\$[0-9,]*\.[0-9]*' "$html_file" | head -1 | sed 's/\$//' | sed 's/,//')
    fi
    
    # Extract 24h change
    local change_24h=$(grep -o '"percent_change_24h":[^,]*' "$html_file" | head -1 | cut -d':' -f2)
    
    # Extract market cap
    local market_cap=$(grep -o '"market_cap":[^,]*' "$html_file" | head -1 | cut -d':' -f2)
    
    # Extract volume 24h
    local volume_24h=$(grep -o '"volume_24h":[^,]*' "$html_file" | head -1 | cut -d':' -f2)
    
    # Validate and clean data
    if [ -n "$price" ] && [[ "$price" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        # Format data for database insertion
        echo "$timestamp,$price,$change_24h,$market_cap,$volume_24h" > "$DATA_DIR/bitcoin_data.csv"
        log_message "Data parsed successfully: Price=$price, 24h Change=$change_24h%"
    else
        handle_error "Failed to extract valid price data"
    fi
}

# Function to initialize database
init_database() {
    log_message "Initializing database..."
    
    # Create database if it doesn't exist
    $MYSQL_PATH -u $DB_USER -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;" 2>/dev/null
    
    if [ $? -ne 0 ]; then
        handle_error "Failed to create database"
    fi
    
    # Create table if it doesn't exist
    $MYSQL_PATH -u $DB_USER -e "
        USE $DB_NAME;
        CREATE TABLE IF NOT EXISTS bitcoin_prices (
            id INT AUTO_INCREMENT PRIMARY KEY,
            timestamp DATETIME NOT NULL,
            price_usd DECIMAL(20,8) NOT NULL,
            change_24h DECIMAL(10,4),
            market_cap BIGINT,
            volume_24h BIGINT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    " 2>/dev/null
    
    if [ $? -ne 0 ]; then
        handle_error "Failed to create table"
    fi
    
    log_message "Database initialized successfully"
}

# Function to insert data into database
insert_data() {
    log_message "Inserting data into database..."
    
    local csv_file="$DATA_DIR/bitcoin_data.csv"
    
    if [ ! -f "$csv_file" ]; then
        handle_error "No data file found to insert"
    fi
    
    # Read CSV and insert into database
    while IFS=',' read -r timestamp price change_24h market_cap volume_24h; do
        # Handle NULL values
        change_24h=${change_24h:-NULL}
        market_cap=${market_cap:-NULL}
        volume_24h=${volume_24h:-NULL}
        
        $MYSQL_PATH -u $DB_USER -e "
            USE $DB_NAME;
            INSERT INTO bitcoin_prices (timestamp, price_usd, change_24h, market_cap, volume_24h) 
            VALUES ('$timestamp', $price, $change_24h, $market_cap, $volume_24h);
        " 2>/dev/null
        
        if [ $? -eq 0 ]; then
            log_message "Data inserted successfully: $timestamp, $price"
        else
            log_message "Failed to insert data for $timestamp"
        fi
    done < "$csv_file"
}

# Main execution function
main() {
    log_message "Starting Bitcoin price data collection..."
    
    # Check network connectivity
    check_network
    
    # Initialize database
    init_database
    
    # Fetch data
    fetch_coinmarketcap_data
    
    # Parse data
    parse_bitcoin_data
    
    # Insert into database
    insert_data
    
    log_message "Data collection completed successfully"
}

# Execute main function
main "$@"