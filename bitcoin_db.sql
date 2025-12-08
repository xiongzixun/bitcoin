DROP DATABASE IF EXISTS bitcoin_tracker;

CREATE DATABASE bitcoin_tracker CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE bitcoin_tracker;

CREATE TABLE bitcoin_prices (
    id INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique identifier for each price record',
    
    collection_date DATE NOT NULL COMMENT 'Date when data was collected',
    collection_time TIME NOT NULL COMMENT 'Time when data was collected',
    
    price_usd DECIMAL(12,2) NOT NULL COMMENT 'Bitcoin price in USD',
    price_24h_high DECIMAL(12,2) DEFAULT NULL COMMENT '24-hour highest price',
    price_24h_low DECIMAL(12,2) DEFAULT NULL COMMENT '24-hour lowest price',
    
    price_change_24h DECIMAL(12,2) DEFAULT NULL COMMENT '24-hour price change amount in USD',
    price_change_percentage DECIMAL(5,2) DEFAULT NULL COMMENT '24-hour price change percentage',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp',
    
    INDEX idx_date (collection_date),
    INDEX idx_datetime (collection_date, collection_time),
    INDEX idx_created (created_at)
    
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Historical Bitcoin price data collected hourly';

CREATE TABLE cryptocurrency_rates (
    id INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique identifier for each rate record',
    
    collection_date DATE NOT NULL COMMENT 'Date when data was collected',
    collection_time TIME NOT NULL COMMENT 'Time when data was collected',
    
    currency_code VARCHAR(10) NOT NULL COMMENT 'Currency code (EUR, GBP, etc.)',
    currency_name VARCHAR(50) DEFAULT NULL COMMENT 'Full currency name',
    
    rate_usd DECIMAL(12,2) NOT NULL COMMENT 'Bitcoin exchange rate in this currency',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp',
    
    INDEX idx_currency (currency_code),
    INDEX idx_date (collection_date),
    INDEX idx_currency_date (currency_code, collection_date)
    
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Additional cryptocurrency exchange rates';

INSERT INTO bitcoin_prices 
(collection_date, collection_time, price_usd, price_24h_high, price_24h_low, price_change_24h, price_change_percentage) 
VALUES
('2025-12-01', '08:00:00', 42350.75, 43197.77, 41503.74, 520.50, 1.24),
('2025-12-01', '09:00:00', 42420.30, 43268.71, 41571.89, 590.05, 1.41),
('2025-12-01', '10:00:00', 42380.15, 43227.75, 41532.55, 549.90, 1.31),
('2025-12-01', '11:00:00', 42450.80, 43298.82, 41602.78, 620.55, 1.48),
('2025-12-01', '12:00:00', 42390.50, 43238.31, 41542.69, 560.25, 1.34);

INSERT INTO cryptocurrency_rates 
(collection_date, collection_time, currency_code, currency_name, rate_usd) 
VALUES
('2025-12-01', '08:00:00', 'EUR', 'Euro', 39850.25),
('2025-12-01', '08:00:00', 'GBP', 'British Pound', 33420.60),
('2025-12-01', '09:00:00', 'EUR', 'Euro', 39915.50),
('2025-12-01', '09:00:00', 'GBP', 'British Pound', 33475.20);

DESCRIBE bitcoin_prices;
DESCRIBE cryptocurrency_rates;

SELECT 'Bitcoin Prices Sample Data:' as '';
SELECT * FROM bitcoin_prices LIMIT 5;

SELECT '' as '';
SELECT 'Cryptocurrency Rates Sample Data:' as '';
SELECT * FROM cryptocurrency_rates LIMIT 5;

SELECT 
    'bitcoin_prices' as table_name,
    COUNT(*) as total_records,
    MIN(collection_date) as earliest_date,
    MAX(collection_date) as latest_date
FROM bitcoin_prices
UNION ALL
SELECT 
    'cryptocurrency_rates' as table_name,
    COUNT(*) as total_records,
    MIN(collection_date) as earliest_date,
    MAX(collection_date) as latest_date
FROM cryptocurrency_rates;

SELECT 'Database schema created successfully!' as Status;
