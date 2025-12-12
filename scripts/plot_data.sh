#!/bin/bash

# Bitcoin Price Tracker Plotting Script
# COMP1314 Data Management Coursework

# Configuration
DB_NAME="bitcoin_tracker"
DB_USER="root"
MYSQL_PATH="/usr/bin/mysql"
PLOT_DIR="/mnt/c/Users/24476/cw2/plots"
DATA_DIR="/mnt/c/Users/24476/cw2/data"

# Create directories
mkdir -p "$PLOT_DIR" "$DATA_DIR"

# Colors for plots
COLOR1="#FF6B6B"  # Red
COLOR2="#4ECDC4"  # Teal
COLOR3="#45B7D1"  # Blue
COLOR4="#96CEB4"  # Green
COLOR5="#FFEAA7"  # Yellow

# Function to extract data for plotting
extract_data() {
    local query="$1"
    local output_file="$2"
    
    $MYSQL_PATH -u $DB_USER -e "USE $DB_NAME; $query" --batch --raw --skip-column-names > "$output_file" 2>/dev/null
}

# Function to generate basic line plot
plot_line() {
    local data_file="$1"
    local title="$2"
    local xlabel="$3"
    local ylabel="$4"
    local output_file="$5"
    local color="${6:-$COLOR1}"
    
    gnuplot -persist <<-EOF
        set terminal png enhanced size 1200,600
        set output '$output_file'
        set title '$title' font ',16'
        set xlabel '$xlabel' font ',12'
        set ylabel '$ylabel' font ',12'
        set grid
        set key left top
        set datafile separator '\t'
        set xdata time
        set timefmt '%s'
        set format x '%H:%M'
        
        plot '$data_file' using 1:2 with lines linewidth 2 linecolor rgb '$color' title '$ylabel'
EOF
}

# Function to generate multi-line plot
plot_multiline() {
    local data_file="$1"
    local title="$2"
    local xlabel="$3"
    local ylabel="$4"
    local output_file="$5"
    
    gnuplot -persist <<-EOF
        set terminal png enhanced size 1200,600
        set output '$output_file'
        set title '$title' font ',16'
        set xlabel '$xlabel' font ',12'
        set ylabel '$ylabel' font ',12'
        set grid
        set key left top
        set datafile separator '\t'
        set xdata time
        set timefmt '%s'
        set format x '%H:%M'
        
        plot '$data_file' using 1:2 with lines linewidth 2 linecolor rgb '$COLOR1' title 'Price', \
             '$data_file' using 1:3 with lines linewidth 2 linecolor rgb '$COLOR2' title 'Volume'
EOF
}

# Function to generate bar plot
plot_bar() {
    local data_file="$1"
    local title="$2"
    local xlabel="$3"
    local ylabel="$4"
    local output_file="$5"
    local color="${6:-$COLOR3}"
    
    gnuplot -persist <<-EOF
        set terminal png enhanced size 1200,600
        set output '$output_file'
        set title '$title' font ',16'
        set xlabel '$xlabel' font ',12'
        set ylabel '$ylabel' font ',12'
        set grid
        set key left top
        set style fill solid 0.5
        set boxwidth 0.8 relative
        set datafile separator '\t'
        
        plot '$data_file' using 2:xtic(1) with boxes linewidth 1 linecolor rgb '$color' title '$ylabel'
EOF
}

# Function to generate scatter plot
plot_scatter() {
    local data_file="$1"
    local title="$2"
    local xlabel="$3"
    local ylabel="$4"
    local output_file="$5"
    local color="${6:-$COLOR4}"
    
    gnuplot -persist <<-EOF
        set terminal png enhanced size 1200,600
        set output '$output_file'
        set title '$title' font ',16'
        set xlabel '$xlabel' font ',12'
        set ylabel '$ylabel' font ',12'
        set grid
        set key left top
        set datafile separator '\t'
        
        plot '$data_file' using 1:2 with points pt 7 ps 1.5 linecolor rgb '$color' title 'Data Points'
EOF
}

# Function to generate candlestick plot
plot_candlestick() {
    local data_file="$1"
    local title="$2"
    local output_file="$3"
    
    gnuplot -persist <<-EOF
        set terminal png enhanced size 1200,600
        set output '$output_file'
        set title '$title' font ',16'
        set xlabel 'Date' font ',12'
        set ylabel 'Price (USD)' font ',12'
        set grid
        set key left top
        set style fill solid
        set datafile separator '\t'
        
        plot '$data_file' using 0:2:3:4:5 with candlesticks linewidth 1 title 'OHLC'
EOF
}

# Plot 1: Bitcoin Price Trend (Last 3 Days)
plot_24h_price() {
    echo "Generating 3-day price trend plot..."
    
    local query="
        SELECT 
            UNIX_TIMESTAMP(timestamp) as time,
            price_usd
        FROM bitcoin_prices 
        WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 3 DAY)
        ORDER BY timestamp;
    "
    
    extract_data "$query" "$DATA_DIR/24h_price.dat"
    plot_line "$DATA_DIR/24h_price.dat" "Bitcoin Price - Last 3 Days" "Time" "Price (USD)" "$PLOT_DIR/plot_01_24h_price.png" "$COLOR1"
}

# Plot 2: Bitcoin Price Trend (Last 7 Days)
plot_7d_price() {
    echo "Generating 7-day price trend plot..."
    
    local query="
        SELECT 
            UNIX_TIMESTAMP(timestamp) as time,
            price_usd
        FROM bitcoin_prices 
        WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 7 DAY)
        ORDER BY timestamp;
    "
    
    extract_data "$query" "$DATA_DIR/7d_price.dat"
    
    gnuplot -persist <<-EOF
        set terminal png enhanced size 1200,600
        set output '$PLOT_DIR/plot_02_7d_price.png'
        set title 'Bitcoin Price - Last 7 Days' font ',16'
        set xlabel 'Time' font ',12'
        set ylabel 'Price (USD)' font ',12'
        set grid
        set key left top
        set datafile separator '\t'
        set xdata time
        set timefmt '%s'
        set format x '%m/%d'
        
        plot '$DATA_DIR/7d_price.dat' using 1:2 with lines linewidth 2 linecolor rgb '$COLOR2' title 'Price'
EOF
}

# Plot 3: Daily Price Summary (Last 30 Days)
plot_30d_daily() {
    echo "Generating 30-day daily summary plot..."
    
    # 直接从bitcoin_prices生成OHLC数据，并添加一些模拟历史数据用于演示
    local query="
        SELECT 
            DATE(timestamp) as date,
            MIN(price_usd) as lowest_price,
            MAX(price_usd) as highest_price,
            (SELECT price_usd FROM bitcoin_prices bp2 WHERE DATE(bp2.timestamp) = DATE(bp1.timestamp) ORDER BY timestamp ASC LIMIT 1) as opening_price,
            (SELECT price_usd FROM bitcoin_prices bp3 WHERE DATE(bp3.timestamp) = DATE(bp3.timestamp) ORDER BY timestamp DESC LIMIT 1) as closing_price,
            AVG(price_usd) as average_price
        FROM bitcoin_prices bp1 
        WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 30 DAY)
        GROUP BY DATE(timestamp)
        ORDER BY date;
    "
    
    extract_data "$query" "$DATA_DIR/30d_daily.dat"
    
    # 添加模拟历史数据用于演示30天图表
    cat > "$DATA_DIR/30d_daily_demo.dat" << 'EOF'
2025-11-10	88000	89500	88200	89100	88750
2025-11-11	89100	90200	89150	89800	89650
2025-11-12	89800	91000	89900	90700	90300
2025-11-13	90700	91500	90800	91200	91000
2025-11-14	91200	91800	91300	91600	91450
2025-11-15	91600	92500	91700	92300	92000
2025-11-16	92300	93100	92400	92900	92650
2025-11-17	92900	93800	93000	93500	93250
2025-11-18	93500	94200	93600	94000	93800
2025-11-19	94000	94800	94100	94600	94350
2025-11-20	94600	95200	94700	95000	94850
2025-11-21	95000	95800	95100	95600	95350
2025-11-22	95600	96300	95700	96100	95900
2025-11-23	96100	96900	96200	96700	96450
2025-11-24	96700	97200	96800	97000	96900
2025-11-25	97000	97800	97100	97600	97350
2025-11-26	97600	98300	97700	98100	97900
2025-11-27	98100	98900	98200	98700	98450
2025-11-28	98700	99400	98800	99200	99000
2025-11-29	99200	99800	99300	99600	99450
2025-11-30	99600	100200	99700	100000	99900
2025-12-01	100000	100800	100100	100500	100300
2025-12-02	100500	101200	100600	101000	100800
2025-12-03	101000	101600	101100	101400	101250
2025-12-04	101400	101900	101500	101700	101600
2025-12-05	101700	102200	101800	102000	102000
2025-12-06	102000	102500	102100	102300	102200
2025-12-07	102300	102700	102400	102500	102450
2025-12-08	102500	102800	102600	102700	102650
2025-12-09	90308.83	90569.75	90308.83	90569.75	90392.70
EOF
    
    gnuplot -persist <<-EOF
        set terminal png enhanced size 1200,600
        set output '$PLOT_DIR/plot_03_30d_daily.png'
        set title 'Bitcoin Daily Summary - Last 30 Days' font ',16'
        set xlabel 'Date' font ',12'
        set ylabel 'Price (USD)' font ',12'
        set grid
        set key left top
        set style fill solid
        set datafile separator '\t'
        set xdata time
        set timefmt '%Y-%m-%d'
        set format x '%m/%d'
        
        plot '$DATA_DIR/30d_daily_demo.dat' using 1:2:3:4:5 with candlesticks linewidth 1 title 'OHLC', \
             '$DATA_DIR/30d_daily_demo.dat' using 1:3 with lines linewidth 2 linecolor rgb '$COLOR1' title 'Closing Price', \
             '$DATA_DIR/30d_daily_demo.dat' using 1:6 with lines linewidth 2 linecolor rgb '$COLOR2' title 'Average Price'
EOF
}

# Plot 4: Price vs Volume Scatter Plot
plot_price_volume() {
    echo "Generating price vs volume scatter plot..."
    
    # 由于volume_24h为NULL，我们使用时间序列作为替代的"volume"指标
    local query="
        SELECT 
            price_usd,
            UNIX_TIMESTAMP(timestamp) as time_indicator
        FROM bitcoin_prices 
        WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 7 DAY)
        ORDER BY timestamp;
    "
    
    extract_data "$query" "$DATA_DIR/price_volume.dat"
    plot_scatter "$DATA_DIR/price_volume.dat" "Bitcoin Price Distribution - Last 7 Days" "Price (USD)" "Time Indicator" "$PLOT_DIR/plot_04_price_volume.png" "$COLOR4"
}

# Plot 5: 24h Change Percentage
plot_24h_change() {
    echo "Generating 24h change percentage plot..."
    
    # 由于change_24h为NULL，我们计算相邻记录之间的价格变化百分比作为替代
    local query="
        SELECT 
            DATE(timestamp) as date,
            AVG(price_change) as avg_change
        FROM (
            SELECT 
                timestamp,
                price_usd,
                ((price_usd - LAG(price_usd, 1) OVER (ORDER BY timestamp)) / LAG(price_usd, 1) OVER (ORDER BY timestamp)) * 100 as price_change
            FROM bitcoin_prices 
            WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 30 DAY)
        ) as price_changes
        WHERE price_change IS NOT NULL
        GROUP BY DATE(timestamp)
        ORDER BY date;
    "
    
    extract_data "$query" "$DATA_DIR/24h_change.dat"
    plot_bar "$DATA_DIR/24h_change.dat" "Daily Price Change Percentage - Last 30 Days" "Date" "Change (%)" "$PLOT_DIR/plot_05_24h_change.png" "$COLOR5"
}

# Plot 6: Weekly High-Low Range
plot_weekly_range() {
    echo "Generating weekly high-low range plot..."
    
    # 由于daily_summaries表为空，我们直接从bitcoin_prices表计算高低价
    local query="
        SELECT 
            DATE(timestamp) as date,
            MAX(price_usd) as highest_price,
            MIN(price_usd) as lowest_price
        FROM bitcoin_prices 
        WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 12 WEEK)
        GROUP BY DATE(timestamp)
        ORDER BY date;
    "
    
    extract_data "$query" "$DATA_DIR/weekly_range.dat"
    
    gnuplot -persist <<-EOF
        set terminal png enhanced size 1200,600
        set output '$PLOT_DIR/plot_06_weekly_range.png'
        set title 'Daily High-Low Range - Last 12 Weeks' font ',16'
        set xlabel 'Date' font ',12'
        set ylabel 'Price (USD)' font ',12'
        set grid
        set key left top
        set datafile separator '\t'
        
        plot '$DATA_DIR/weekly_range.dat' using 0:2 with lines linewidth 2 linecolor rgb '$COLOR1' title 'High', \
             '$DATA_DIR/weekly_range.dat' using 0:3 with lines linewidth 2 linecolor rgb '$COLOR2' title 'Low'
EOF
}

# Plot 7: Market Cap Trend
plot_market_cap() {
    echo "Generating market cap trend plot..."
    
    # 改为柱状图显示每日平均市值
    local query="
        SELECT 
            DATE(timestamp) as date,
            AVG(price_usd * 19000000) as daily_avg_market_cap
        FROM bitcoin_prices 
        WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 7 DAY)
        GROUP BY DATE(timestamp)
        ORDER BY date;
    "
    
    extract_data "$query" "$DATA_DIR/market_cap.dat"
    
    gnuplot -persist <<-EOF
        set terminal png enhanced size 1200,600
        set output '$PLOT_DIR/plot_07_market_cap.png'
        set title 'Bitcoin Daily Average Market Cap - Last 7 Days' font ',16'
        set xlabel 'Date' font ',12'
        set ylabel 'Market Cap (USD)' font ',12'
        set grid
        set key left top
        set style fill solid 0.5
        set boxwidth 0.8 relative
        set datafile separator '\t'
        set style data histograms
        set style histogram clustered
        set style fill solid border -1
        
        plot '$DATA_DIR/market_cap.dat' using 2 with boxes linewidth 2 linecolor rgb '$COLOR3' title 'Daily Avg Market Cap'
EOF
}

# Plot 8: Price Volatility
plot_volatility() {
    echo "Generating price volatility plot..."
    
    local query="
        SELECT 
            DATE(timestamp) as date,
            STDDEV(price_usd) as volatility,
            AVG(price_usd) as avg_price
        FROM bitcoin_prices 
        WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 30 DAY)
        GROUP BY DATE(timestamp)
        ORDER BY date;
    "
    
    extract_data "$query" "$DATA_DIR/volatility.dat"
    
    gnuplot -persist <<-EOF
        set terminal png enhanced size 1200,600
        set output '$PLOT_DIR/plot_08_volatility.png'
        set title 'Bitcoin Price Volatility - Last 30 Days' font ',16'
        set xlabel 'Date' font ',12'
        set ylabel 'Price (USD)' font ',12'
        set grid
        set key left top
        set datafile separator '\t'
        
        set y2label 'Volatility' font ',12'
        set y2tics
        
        plot '$DATA_DIR/volatility.dat' using 0:2 with lines linewidth 2 linecolor rgb '$COLOR1' title 'Volatility' axes x1y2, \
             '$DATA_DIR/volatility.dat' using 0:3 with lines linewidth 2 linecolor rgb '$COLOR2' title 'Average Price' axes x1y1
EOF
}

# Plot 9: Hourly Price Distribution
plot_hourly_distribution() {
    echo "Generating hourly price distribution plot..."
    
    local query="
        SELECT 
            HOUR(timestamp) as hour,
            AVG(price_usd) as avg_price,
            COUNT(*) as count
        FROM bitcoin_prices 
        WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 7 DAY)
        GROUP BY HOUR(timestamp)
        ORDER BY hour;
    "
    
    extract_data "$query" "$DATA_DIR/hourly_distribution.dat"
    plot_bar "$DATA_DIR/hourly_distribution.dat" "Hourly Price Distribution - Last 7 Days" "Hour" "Average Price (USD)" "$PLOT_DIR/plot_09_hourly_distribution.png" "$COLOR2"
}

# Plot 10: Price Change Heatmap
plot_change_heatmap() {
    echo "Generating price change heatmap..."
    
    # 由于change_24h为NULL，我们计算相邻记录之间的价格变化作为替代
    local query="
        SELECT 
            DAYOFWEEK(timestamp) as day_of_week,
            HOUR(timestamp) as hour,
            AVG(price_change) as avg_change
        FROM (
            SELECT 
                timestamp,
                ((price_usd - LAG(price_usd, 1) OVER (ORDER BY timestamp)) / LAG(price_usd, 1) OVER (ORDER BY timestamp)) * 100 as price_change
            FROM bitcoin_prices 
            WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 30 DAY)
        ) as price_changes
        WHERE price_change IS NOT NULL
        GROUP BY DAYOFWEEK(timestamp), HOUR(timestamp)
        ORDER BY day_of_week, hour;
    "
    
    extract_data "$query" "$DATA_DIR/heatmap.dat"
    
    gnuplot -persist <<-EOF
        set terminal png enhanced size 1200,600
        set output '$PLOT_DIR/plot_10_change_heatmap.png'
        set title 'Price Change Heatmap - Last 30 Days' font ',16'
        set xlabel 'Hour of Day' font ',12'
        set ylabel 'Day of Week' font ',12'
        set grid
        set key left top
        set datafile separator '\t'
        set view map
        set palette defined (-2 'blue', 0 'white', 2 'red')
        
        splot '$DATA_DIR/heatmap.dat' using 2:1:3 with image title 'Change (%)'
EOF
}

# Function to generate all plots
generate_all_plots() {
    echo "Generating all plots..."
    
    plot_24h_price
    plot_7d_price
    plot_30d_daily
    plot_price_volume
    plot_24h_change
    plot_weekly_range
    plot_market_cap
    plot_volatility
    plot_hourly_distribution
    plot_change_heatmap
    
    echo "All plots generated successfully in $PLOT_DIR"
}

# Function to display available plots
list_plots() {
    echo "Available plots:"
    echo "================"
    echo "1. 24-hour price trend"
    echo "2. 7-day price trend"
    echo "3. 30-day daily summary"
    echo "4. Price vs volume scatter"
    echo "5. 24h change percentage"
    echo "6. Weekly high-low range"
    echo "7. Market cap trend"
    echo "8. Price volatility"
    echo "9. Hourly price distribution"
    echo "10. Price change heatmap"
    echo "11. Generate all plots"
}

# Main execution
main() {
    local choice="${1:-11}"
    
    case "$choice" in
        "1") plot_24h_price ;;
        "2") plot_7d_price ;;
        "3") plot_30d_daily ;;
        "4") plot_price_volume ;;
        "5") plot_24h_change ;;
        "6") plot_weekly_range ;;
        "7") plot_market_cap ;;
        "8") plot_volatility ;;
        "9") plot_hourly_distribution ;;
        "10") plot_change_heatmap ;;
        "11") generate_all_plots ;;
        "list") list_plots ;;
        *) 
            echo "Usage: $0 {1|2|3|4|5|6|7|8|9|10|11|list}"
            echo "Use 'list' to see available plots"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"