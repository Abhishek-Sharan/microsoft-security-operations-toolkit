#!/bin/bash

# Enhanced System Performance Monitor for Azure Monitor Agent
# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BRIGHT_GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display colored output
display_message() {
    MESSAGE="$1"
    COLOR="$2"
    if [[ -n "$COLOR" ]]; then
        echo -e "${COLOR}$MESSAGE${NC}"
    else
        echo "$MESSAGE"
    fi
}

# Function to get load average status
get_load_status() {
    local load=$1
    local cpu_cores=$(nproc)
    local load_num=$(echo "$load" | awk '{print $1}')
    local load_ratio=$(echo "$load_num $cpu_cores" | awk '{printf "%.2f", $1/$2}')
    
    if (( $(echo "$load_ratio > 1.0" | bc -l) )); then
        echo "HIGH ($load_ratio)"
    elif (( $(echo "$load_ratio > 0.7" | bc -l) )); then
        echo "MODERATE ($load_ratio)"
    else
        echo "NORMAL ($load_ratio)"
    fi
}

# Function to get memory usage percentage
get_memory_percentage() {
    free | awk '/Mem:/ {printf "%.1f", ($3/$2)*100}'
}

# Function to get disk usage percentage
get_disk_percentage() {
    df / | awk 'NR==2 {gsub(/%/,"",$5); print $5}'
}

# Function to format cache size comparison
format_cache_usage() {
    local used=$1
    local configured=$2
    if [[ -n "$configured" && "$configured" -gt 0 ]]; then
        local percentage=$(echo "$used $configured" | awk '{printf "%.1f", ($1/$2)*100}')
        echo "$used MB of $configured MB (${percentage}%)"
    else
        echo "$used MB (config not found)"
    fi
}

# Get system information
HOSTNAME=$(hostname)
DATENOW=$(date +"%Y-%m-%d %H:%M:%S %Z")
CPU_CORES=$(nproc)

# Get system performance metrics
LOAD_AVG=$(uptime | awk -F'load average:' '{ print $2 }' | xargs)
LOAD_STATUS=$(get_load_status "$LOAD_AVG")

# Memory metrics
MEMORY_STATS=$(free -m | awk '/Mem:/ {printf "%d,%d,%d", $2, $3, $4}')
IFS=',' read -r TOTAL_MEM USED_MEM FREE_MEM <<< "$MEMORY_STATS"
MEMORY_PERCENT=$(get_memory_percentage)

# Disk metrics
DISK_STATS=$(df -BM / | awk 'NR==2 {gsub(/M/,"",$2); gsub(/M/,"",$3); gsub(/M/,"",$4); printf "%d,%d,%d", $2, $3, $4}')
IFS=',' read -r TOTAL_DISK USED_DISK FREE_DISK <<< "$DISK_STATS"
DISK_PERCENT=$(get_disk_percentage)

# AMA specific metrics
AMA_CACHE_SIZE=$(du -sBM /var/opt/microsoft/azuremonitoragent/events/ 2>/dev/null | awk '{gsub(/M/,"",$1); print $1}' || echo "0")
AMA_CACHE_CONFIG=$(grep -o '"name":"MaxDiskQuotaInMB","value":"[^"]*"' /etc/opt/microsoft/azuremonitoragent/config-cache/configchunks/*.json 2>/dev/null | sed 's/.*"value":"\([^"]*\)".*/\1/' | head -1 || echo "")
CACHE_USAGE=$(format_cache_usage "$AMA_CACHE_SIZE" "$AMA_CACHE_CONFIG")

# Get last throttle event
LAST_THROTTLE=$(tac /var/opt/microsoft/azuremonitoragent/log/mdsd.warn 2>/dev/null | grep -m1 "Throttling ingestion" || echo "No throttling events found")

# Display formatted output
echo -e "\n${BRIGHT_GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BRIGHT_GREEN}║            📊 AZURE MONITOR AGENT PERFORMANCE REPORT      ║${NC}"
echo -e "${BRIGHT_GREEN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

# System Information
display_message "🖥️  System Information" "$CYAN"
display_message "   ├─ Hostname: $HOSTNAME" "$NC"
display_message "   ├─ CPU Cores: $CPU_CORES" "$NC"
display_message "   └─ Scan Time: $DATENOW" "$NC"
echo ""

# Performance Metrics
display_message "⚡ Performance Metrics" "$CYAN"

# Load Average with color coding
if [[ "$LOAD_STATUS" == *"HIGH"* ]]; then
    display_message "   ├─ Load Average: $LOAD_AVG [$LOAD_STATUS]" "$RED"
elif [[ "$LOAD_STATUS" == *"MODERATE"* ]]; then
    display_message "   ├─ Load Average: $LOAD_AVG [$LOAD_STATUS]" "$YELLOW"
else
    display_message "   ├─ Load Average: $LOAD_AVG [$LOAD_STATUS]" "$GREEN"
fi

# Memory Usage with color coding
if (( $(echo "$MEMORY_PERCENT > 90" | bc -l) )); then
    display_message "   ├─ Memory: ${USED_MEM}MB / ${TOTAL_MEM}MB (${MEMORY_PERCENT}%) [HIGH]" "$RED"
elif (( $(echo "$MEMORY_PERCENT > 75" | bc -l) )); then
    display_message "   ├─ Memory: ${USED_MEM}MB / ${TOTAL_MEM}MB (${MEMORY_PERCENT}%) [MODERATE]" "$YELLOW"
else
    display_message "   ├─ Memory: ${USED_MEM}MB / ${TOTAL_MEM}MB (${MEMORY_PERCENT}%)" "$GREEN"
fi

# Disk Usage with color coding
if [[ "$DISK_PERCENT" -gt 90 ]]; then
    display_message "   └─ Disk: ${USED_DISK}MB / ${TOTAL_DISK}MB (${DISK_PERCENT}%) [HIGH]" "$RED"
elif [[ "$DISK_PERCENT" -gt 75 ]]; then
    display_message "   └─ Disk: ${USED_DISK}MB / ${TOTAL_DISK}MB (${DISK_PERCENT}%) [MODERATE]" "$YELLOW"
else
    display_message "   └─ Disk: ${USED_DISK}MB / ${TOTAL_DISK}MB (${DISK_PERCENT}%)" "$GREEN"
fi
echo ""

# AMA Specific Metrics
display_message "🔍 Azure Monitor Agent Status" "$CYAN"
display_message "   ├─ Cache Usage: $CACHE_USAGE" "$NC"

# Throttling status
if [[ "$LAST_THROTTLE" == "No throttling events found" ]]; then
    display_message "   └─ Throttling: ✅ No recent throttling detected" "$GREEN"
else
    display_message "   └─ Last Throttle: ⚠️  $(echo "$LAST_THROTTLE" | cut -c1-60)..." "$YELLOW"
fi
echo ""

# Summary Status
display_message "📈 Overall Status" "$CYAN"
ISSUES=0

if [[ "$LOAD_STATUS" == *"HIGH"* ]]; then ((ISSUES++)); fi
if (( $(echo "$MEMORY_PERCENT > 90" | bc -l) )); then ((ISSUES++)); fi
if [[ "$DISK_PERCENT" -gt 90 ]]; then ((ISSUES++)); fi
if [[ "$LAST_THROTTLE" != "No throttling events found" ]]; then ((ISSUES++)); fi

if [[ $ISSUES -eq 0 ]]; then
    display_message "   └─ System Status: ✅ All systems operating normally" "$GREEN"
elif [[ $ISSUES -eq 1 ]]; then
    display_message "   └─ System Status: ⚠️  1 potential issue detected" "$YELLOW"
else
    display_message "   └─ System Status: ❌ $ISSUES potential issues detected" "$RED"
fi

echo -e "\n${BRIGHT_GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"

# Log to syslog (clean versions without colors)
logger -t agentperf -p local0.info "System Load: $LOAD_AVG [$LOAD_STATUS] | Memory: ${MEMORY_PERCENT}% | Disk: ${DISK_PERCENT}% | Issues: $ISSUES [$DATENOW]"
logger -t agentperf -p local0.info "AMA Cache: $CACHE_USAGE [$DATENOW]"
if [[ "$LAST_THROTTLE" != "No throttling events found" ]]; then
    logger -t agentperf -p local0.info "AMA Throttling: $LAST_THROTTLE [$DATENOW]"
fi
