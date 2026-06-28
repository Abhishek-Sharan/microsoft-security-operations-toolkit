#!/bin/bash

# System metrics
LOAD=$(uptime | awk -F'load average:' '{print $2}' | xargs)
MEM=$(free -m | awk '/Mem:/ {printf "Used: %dMB, Free: %dMB", $3, $4}')
DISK=$(df -BM / | awk 'NR==2 {printf "Used: %s, Available: %s", $3, $4}')

# AMA cache usage (in MB)
CACHE=$(du -sBM /var/opt/microsoft/azuremonitoragent/events/ 2>/dev/null | awk '{gsub(/M/,"",$1); print $1}')
CACHE="${CACHE:-Unavailable}"

# Last AMA throttle event
THROTTLE=$(tac /var/opt/microsoft/azuremonitoragent/log/mdsd.warn 2>/dev/null | grep -m1 "Throttling ingestion")
THROTTLE="${THROTTLE:-No recent throttling found}"

# Output and log
echo "Load: $LOAD | Memory: $MEM | Disk: $DISK"
echo "AMA Cache: ${CACHE}MB"
echo "AMA Last Throttle: $THROTTLE"

logger -t agentperf -p local0.info "Load: $LOAD | Memory: $MEM | Disk: $DISK"
logger -t agentperf -p local0.info "AMA Cache: ${CACHE}MB"
logger -t agentperf -p local0.info "AMA Last Throttle: $THROTTLE"
