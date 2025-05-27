#!/bin/bash

# Disk Usage Management Script
# This script monitors disk usage, cleans up when thresholds are exceeded,
# and sends email notifications about actions taken.

# Configuration variables
THRESHOLD=85                      # Disk usage percentage threshold to trigger cleanup
LOG_DIR="/var/log"                # Directory containing log files to clean
BACKUP_DIR="/var/backups"         # Directory for backups that can be cleaned
TEMP_DIR="/tmp"                   # Temporary directory to clean
LOG_FILE="/var/log/disk_cleanup.log"  # Log file for this script
ADMIN_EMAIL="admin@example.com"   # Email to send notifications to
EMAIL_SUBJECT="Disk Usage Alert"  # Email subject

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to send email
send_email() {
    local subject="$1"
    local message="$2"
    
    echo "$message" | mail -s "$subject" "$ADMIN_EMAIL"
    log_message "Email notification sent to $ADMIN_EMAIL"
}

# Function to check disk usage
check_disk_usage() {
    local partition="$1"
    local usage=$(df -h "$partition" | grep -v Filesystem | awk '{print $5}' | tr -d '%')
    
    echo "$usage"
}

# Function to clean log files older than X days
clean_old_logs() {
    local days="$1"
    log_message "Cleaning log files older than $days days"
    
    find "$LOG_DIR" -name "*.log" -type f -mtime +$days -exec rm -f {} \; 2>/dev/null
    find "$LOG_DIR" -name "*.gz" -type f -mtime +$days -exec rm -f {} \; 2>/dev/null
}

# Function to clean temporary files
clean_temp_files() {
    log_message "Cleaning temporary files"
    
    find "$TEMP_DIR" -type f -mtime +7 -exec rm -f {} \; 2>/dev/null
}

# Function to clean old backups
clean_old_backups() {
    local days="$1"
    log_message "Cleaning backup files older than $days days"
    
    find "$BACKUP_DIR" -type f -mtime +$days -exec rm -f {} \; 2>/dev/null
}

# Function to clean package cache (for apt-based systems)
clean_package_cache() {
    if command -v apt-get &> /dev/null; then
        log_message "Cleaning apt package cache"
        apt-get clean
    fi
}

# Main function
main() {
    # Create log file if it doesn't exist
    touch "$LOG_FILE"
    
    # Check root partition usage
    ROOT_USAGE=$(check_disk_usage "/")
    log_message "Current disk usage: ${ROOT_USAGE}%"
    
    # Initialize email message
    EMAIL_MESSAGE="Disk Usage Report\n"
    EMAIL_MESSAGE+="=================\n\n"
    EMAIL_MESSAGE+="Current disk usage: ${ROOT_USAGE}%\n\n"
    
    # If usage is above threshold, perform cleanup
    if [ "$ROOT_USAGE" -gt "$THRESHOLD" ]; then
        log_message "Disk usage is above threshold (${THRESHOLD}%). Starting cleanup..."
        EMAIL_MESSAGE+="Disk usage exceeded threshold of ${THRESHOLD}%. Cleanup actions performed:\n\n"
        
        # Perform cleanup actions
        clean_temp_files
        EMAIL_MESSAGE+="- Cleaned temporary files\n"
        
        clean_old_logs 30
        EMAIL_MESSAGE+="- Removed log files older than 30 days\n"
        
        clean_old_backups 90
        EMAIL_MESSAGE+="- Removed backup files older than 90 days\n"
        
        clean_package_cache
        EMAIL_MESSAGE+="- Cleaned package cache\n"
        
        # Check usage after cleanup
        NEW_USAGE=$(check_disk_usage "/")
        SPACE_FREED=$((ROOT_USAGE - NEW_USAGE))
        
        log_message "Cleanup completed. New disk usage: ${NEW_USAGE}%"
        EMAIL_MESSAGE+="\nCleanup completed. New disk usage: ${NEW_USAGE}%\n"
        EMAIL_MESSAGE+="Space freed: ${SPACE_FREED}%\n"
        
        # Send email notification
        send_email "$EMAIL_SUBJECT" "$EMAIL_MESSAGE"
    else
        log_message "Disk usage is below threshold. No action needed."
    fi
}

# Execute main function
main
