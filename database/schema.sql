-- Bitcoin Price Tracker Database Schema
-- COMP1314 Data Management Coursework

-- Create database
CREATE DATABASE IF NOT EXISTS bitcoin_tracker;
USE bitcoin_tracker;

-- Main table for Bitcoin price data
CREATE TABLE bitcoin_prices (
    id INT AUTO_INCREMENT PRIMARY KEY,
    timestamp DATETIME NOT NULL,
    price_usd DECIMAL(20,8) NOT NULL,
    change_24h DECIMAL(10,4),
    market_cap BIGINT,
    volume_24h BIGINT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_timestamp (timestamp),
    INDEX idx_price (price_usd)
);

-- Table for daily price summaries
CREATE TABLE daily_summaries (
    id INT AUTO_INCREMENT PRIMARY KEY,
    date DATE NOT NULL UNIQUE,
    opening_price DECIMAL(20,8) NOT NULL,
    closing_price DECIMAL(20,8) NOT NULL,
    highest_price DECIMAL(20,8) NOT NULL,
    lowest_price DECIMAL(20,8) NOT NULL,
    average_price DECIMAL(20,8) NOT NULL,
    total_volume BIGINT DEFAULT 0,
    price_change DECIMAL(10,4),
    price_change_percent DECIMAL(10,4),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_date (date)
);

-- Table for price alerts
CREATE TABLE price_alerts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    alert_type ENUM('ABOVE', 'BELOW') NOT NULL,
    target_price DECIMAL(20,8) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    triggered_at TIMESTAMP NULL,
    INDEX idx_active (is_active),
    INDEX idx_target_price (target_price)
);

-- Table for data collection logs
CREATE TABLE collection_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    collection_time DATETIME NOT NULL,
    status ENUM('SUCCESS', 'FAILED', 'PARTIAL') NOT NULL,
    error_message TEXT,
    records_processed INT DEFAULT 0,
    execution_time_seconds DECIMAL(10,3),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_collection_time (collection_time),
    INDEX idx_status (status)
);

-- Table for cryptocurrency exchanges (for future expansion)
CREATE TABLE exchanges (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    website_url VARCHAR(255),
    api_endpoint VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Table for historical data from different exchanges
CREATE TABLE exchange_prices (
    id INT AUTO_INCREMENT PRIMARY KEY,
    exchange_id INT NOT NULL,
    timestamp DATETIME NOT NULL,
    price_usd DECIMAL(20,8) NOT NULL,
    volume_24h BIGINT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (exchange_id) REFERENCES exchanges(id),
    INDEX idx_exchange_timestamp (exchange_id, timestamp),
    INDEX idx_timestamp (timestamp)
);

-- Insert default exchanges
INSERT INTO exchanges (name, website_url, api_endpoint) VALUES
('CoinMarketCap', 'https://coinmarketcap.com', '/api/v1/cryptocurrency/listings/latest'),
('CoinDesk', 'https://www.coindesk.com', '/price/bitcoin/');

-- Create view for latest price
CREATE VIEW latest_price AS
SELECT 
    bp.*,
    DATE(bp.timestamp) as date_only
FROM bitcoin_prices bp
WHERE bp.timestamp = (
    SELECT MAX(timestamp) 
    FROM bitcoin_prices 
    WHERE DATE(timestamp) = DATE(bp.timestamp)
);

-- Create view for price trends
CREATE VIEW price_trends AS
SELECT 
    DATE(bp.timestamp) as date,
    MIN(bp.price_usd) as daily_low,
    MAX(bp.price_usd) as daily_high,
    AVG(bp.price_usd) as daily_average,
    (SELECT price_usd FROM bitcoin_prices bp2 
     WHERE DATE(bp2.timestamp) = DATE(bp.timestamp) 
     ORDER BY timestamp ASC LIMIT 1) as opening_price,
    (SELECT price_usd FROM bitcoin_prices bp3 
     WHERE DATE(bp3.timestamp) = DATE(bp.timestamp) 
     ORDER BY timestamp DESC LIMIT 1) as closing_price
FROM bitcoin_prices bp
GROUP BY DATE(bp.timestamp)
ORDER BY date DESC;