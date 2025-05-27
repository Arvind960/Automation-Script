#!/bin/bash

# Disk Usage Management Script
# This script monitors disk usage, cleans up when thresholds are exceeded,
# and sends email notifications about actions taken.

# Configuration variables
THRESHOLD=85                      # Disk usage percentage threshold to trigger cleanup
CRITICAL_THRESHOLD=90             # Critical disk usage threshold for urgent alerts
LOG_DIR="/var/log"                # Directory containing log files to clean
BACKUP_DIR="/var/backups"         # Directory for backups that can be cleaned
TEMP_DIR="/tmp"                   # Temporary directory to clean
LOG_FILE="/var/log/disk_cleanup.log"  # Log file for this script
ADMIN_EMAIL="admin@example.com"   # Email to send notifications to
EMAIL_SUBJECT="Disk Usage Alert"  # Email subject
CRITICAL_EMAIL_SUBJECT="CRITICAL: Disk Usage Alert"  # Critical alert email subject

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
    
    # Check if usage is above critical threshold first
    if [ "$ROOT_USAGE" -ge "$CRITICAL_THRESHOLD" ]; then
        log_message "CRITICAL: Disk usage is above critical threshold (${CRITICAL_THRESHOLD}%)!"
        
        # Create critical alert message
        CRITICAL_MESSAGE="!!! CRITICAL DISK USAGE ALERT !!!\n\n"
        CRITICAL_MESSAGE+="Current disk usage: ${ROOT_USAGE}% has exceeded the CRITICAL threshold of ${CRITICAL_THRESHOLD}%\n\n"
        CRITICAL_MESSAGE+="URGENT ACTION REQUIRED!\n\n"
        CRITICAL_MESSAGE+="The system will now attempt emergency cleanup procedures, but manual intervention may be necessary.\n"
        CRITICAL_MESSAGE+="Please investigate immediately to prevent system failure.\n\n"
        
        # Send critical alert immediately
        send_email "$CRITICAL_EMAIL_SUBJECT" "$CRITICAL_MESSAGE"
        
        # Perform more aggressive cleanup for critical situations
        log_message "Performing emergency cleanup procedures..."
        
        # More aggressive cleanup for critical situations
        clean_temp_files
        clean_old_logs 15  # More aggressive - clean logs older than 15 days
        clean_old_backups 60  # More aggressive - clean backups older than 60 days
        clean_package_cache
        
        # Additional aggressive cleanup
        log_message "Performing additional emergency cleanup procedures..."
        find "$TEMP_DIR" -type f -mtime +1 -exec rm -f {} \; 2>/dev/null  # Remove files older than 1 day in temp
        find "$LOG_DIR" -name "*.log" -type f -mtime +7 -exec rm -f {} \; 2>/dev/null  # Remove logs older than 7 days
        
        # Check usage after emergency cleanup
        NEW_USAGE=$(check_disk_usage "/")
        SPACE_FREED=$((ROOT_USAGE - NEW_USAGE))
        
        log_message "Emergency cleanup completed. New disk usage: ${NEW_USAGE}%"
        
        # Send follow-up email with results of emergency cleanup
        FOLLOWUP_MESSAGE="Emergency Cleanup Results\n"
        FOLLOWUP_MESSAGE+="=======================\n\n"
        FOLLOWUP_MESSAGE+="Previous disk usage: ${ROOT_USAGE}%\n"
        FOLLOWUP_MESSAGE+="Current disk usage: ${NEW_USAGE}%\n"
        FOLLOWUP_MESSAGE+="Space freed: ${SPACE_FREED}%\n\n"
        
        if [ "$NEW_USAGE" -ge "$CRITICAL_THRESHOLD" ]; then
            FOLLOWUP_MESSAGE+="WARNING: Disk usage is still above critical threshold!\n"
            FOLLOWUP_MESSAGE+="Manual intervention is required immediately.\n"
        fi
        
        send_email "Follow-up: $CRITICAL_EMAIL_SUBJECT" "$FOLLOWUP_MESSAGE"
        
    # If not critical but above normal threshold, perform standard cleanup
    elif [ "$ROOT_USAGE" -gt "$THRESHOLD" ]; then
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
        
        # Check if we're approaching critical levels after cleanup
        if [ "$NEW_USAGE" -ge "$((CRITICAL_THRESHOLD - 5))" ]; then
            EMAIL_MESSAGE+="\nWARNING: Disk usage is approaching critical levels!\n"
            EMAIL_MESSAGE+="Additional action may be required soon.\n"
        fi
        
        # Send email notification
        send_email "$EMAIL_SUBJECT" "$EMAIL_MESSAGE"
    else
        log_message "Disk usage is below threshold. No action needed."
    fi
}

# Execute main function
main
