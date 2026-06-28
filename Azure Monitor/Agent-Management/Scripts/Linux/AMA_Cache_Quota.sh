#!/bin/bash

# Path to AMA log file
LOG_FILE="/var/opt/microsoft/azuremonitoragent/log/mdsd.info"

# Function to log output (optional to syslog or local file)
log_message() {
    MESSAGE="$1"
    echo "$MESSAGE"
    logger -t ama_cache_check -p local0.info "$MESSAGE"  # Optional: remove if not needed
}

# Check if log file exists
if [[ ! -f "$LOG_FILE" ]]; then
    log_message "❌ AMA log file not found at $LOG_FILE"
    exit 1
fi

# Get the most recent cache size setting
CACHE_LINE=$(tac "$LOG_FILE" | grep -m 1 "Using disk quota specified in AgentSettings")

if [[ -z "$CACHE_LINE" ]]; then
    log_message "⚠️  No disk quota configuration found in AMA logs."
    exit 1
fi

# Extract the numeric cache size (MB) using regex
CACHE_MB=$(echo "$CACHE_LINE" | grep -oP '\d+(?=\s*MB)')

# Final output
log_message "✅ AMA Configured Cache Size: $CACHE_MB MB"
log_message "ℹ️  Log Line: $CACHE_LINE"
