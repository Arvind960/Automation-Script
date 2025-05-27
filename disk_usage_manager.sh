#!/bin/bash

# Disk Usage Management Script
# This script monitors disk usage, cleans up when thresholds are exceeded,
# and sends email notifications about actions taken.

# Configuration variables
THRESHOLD=85                      # Disk usage percentage threshold to trigger cleanup
CRITICAL_THRESHOLD=90             # Critical disk usage threshold for urgent alerts
WARNING_THRESHOLD=75              # Warning threshold for early notification
LOG_DIR="/var/log"                # Directory containing log files to clean
BACKUP_DIR="/var/backups"         # Directory for backups that can be cleaned
TEMP_DIR="/tmp"                   # Temporary directory to clean
LOG_FILE="/var/log/disk_cleanup.log"  # Log file for this script
ADMIN_EMAIL="admin@example.com"   # Email to send notifications to
EMAIL_SUBJECT="Disk Usage Alert"  # Email subject
CRITICAL_EMAIL_SUBJECT="CRITICAL: Disk Usage Alert"  # Critical alert email subject
WARNING_EMAIL_SUBJECT="WARNING: Disk Usage Alert"    # Warning alert email subject
REPEAT_ALERT_FILE="/tmp/disk_alert_timestamp"        # File to track last alert time
REPEAT_ALERT_INTERVAL=30          # Minutes between repeated critical alerts

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

# Function to check if we should send a repeated alert
should_send_repeated_alert() {
    # If the timestamp file doesn't exist, we should send an alert
    if [ ! -f "$REPEAT_ALERT_FILE" ]; then
        return 0  # True in bash
    fi
    
    # Get the last alert timestamp
    local last_alert_time=$(cat "$REPEAT_ALERT_FILE")
    local current_time=$(date +%s)
    local time_diff=$((current_time - last_alert_time))
    local interval_seconds=$((REPEAT_ALERT_INTERVAL * 60))
    
    # If enough time has passed since the last alert, we should send another
    if [ "$time_diff" -ge "$interval_seconds" ]; then
        return 0  # True in bash
    else
        return 1  # False in bash
    fi
}

# Function to update the last alert timestamp
update_alert_timestamp() {
    date +%s > "$REPEAT_ALERT_FILE"
    log_message "Updated alert timestamp for repeated alerts"
}

# Function to send repeated critical alerts
send_repeated_critical_alert() {
    local usage="$1"
    
    # Check if we should send a repeated alert
    if should_send_repeated_alert; then
        log_message "Sending repeated critical alert (disk usage: ${usage}%)"
        
        # Create repeated alert message
        local repeat_message="!!! CRITICAL DISK USAGE ALERT - REMINDER !!!\n\n"
        repeat_message+="Current disk usage: ${usage}% is still above the CRITICAL threshold of ${CRITICAL_THRESHOLD}%\n\n"
        repeat_message+="URGENT ACTION REQUIRED!\n\n"
        repeat_message+="This is a repeated alert. The system is still in a critical state.\n"
        repeat_message+="Please investigate immediately to prevent system failure.\n\n"
        repeat_message+="This alert will continue to be sent every ${REPEAT_ALERT_INTERVAL} minutes until the situation is resolved.\n"
        
        # Send the repeated alert
        send_email "$CRITICAL_EMAIL_SUBJECT - REMINDER" "$repeat_message"
        
        # Update the timestamp
        update_alert_timestamp
        
        return 0  # Alert was sent
    else
        log_message "Skipping repeated alert - not enough time has passed since last alert"
        return 1  # Alert was not sent
    fi
}

# Main function
main() {
    # Create log file if it doesn't exist
    touch "$LOG_FILE"
    
    # Check root partition usage
    ROOT_USAGE=$(check_disk_usage "/")
    log_message "Current disk usage: ${ROOT_USAGE}%"
    
    # Check if this is a repeated alert run
    if [ "$1" = "repeat-check" ]; then
        if [ "$ROOT_USAGE" -ge "$CRITICAL_THRESHOLD" ]; then
            send_repeated_critical_alert "$ROOT_USAGE"
        else
            log_message "Disk usage is below critical threshold. No repeated alert needed."
            # If disk usage is no longer critical, remove the timestamp file
            if [ -f "$REPEAT_ALERT_FILE" ]; then
                rm -f "$REPEAT_ALERT_FILE"
                log_message "Removed alert timestamp file as disk usage is no longer critical"
            fi
        fi
        exit 0
    fi
    
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
        CRITICAL_MESSAGE+="Repeated alerts will be sent every ${REPEAT_ALERT_INTERVAL} minutes until the situation is resolved.\n"
        
        # Send critical alert immediately and update timestamp
        send_email "$CRITICAL_EMAIL_SUBJECT" "$CRITICAL_MESSAGE"
        update_alert_timestamp
        
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
            FOLLOWUP_MESSAGE+="\nThis script will continue to send alerts every ${REPEAT_ALERT_INTERVAL} minutes until the situation is resolved.\n"
        else
            # If cleanup brought usage below critical, remove the timestamp file
            if [ -f "$REPEAT_ALERT_FILE" ]; then
                rm -f "$REPEAT_ALERT_FILE"
                log_message "Removed alert timestamp file as disk usage is no longer critical"
                FOLLOWUP_MESSAGE+="\nDisk usage is now below critical threshold. Repeated alerts have been disabled.\n"
            fi
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
    
    # If above warning threshold but below cleanup threshold, send warning only
    elif [ "$ROOT_USAGE" -ge "$WARNING_THRESHOLD" ]; then
        log_message "Warning: Disk usage is above warning threshold (${WARNING_THRESHOLD}%)."
        
        # Create warning message
        WARNING_MESSAGE="Disk Usage Warning\n"
        WARNING_MESSAGE+="================\n\n"
        WARNING_MESSAGE+="Current disk usage: ${ROOT_USAGE}% has exceeded the warning threshold of ${WARNING_THRESHOLD}%\n\n"
        WARNING_MESSAGE+="While no immediate action is required, disk usage is trending upward.\n"
        WARNING_MESSAGE+="Consider reviewing disk usage and planning for potential cleanup.\n\n"
        WARNING_MESSAGE+="Recommendations:\n"
        WARNING_MESSAGE+="- Review large files and directories using 'du -h --max-depth=1 /'\n"
        WARNING_MESSAGE+="- Check for unused applications that can be removed\n"
        WARNING_MESSAGE+="- Consider archiving or moving old data to external storage\n"
        
        # Send warning email
        send_email "$WARNING_EMAIL_SUBJECT" "$WARNING_MESSAGE"
    else
        log_message "Disk usage is below all thresholds. No action needed."
        
        # If disk usage is no longer critical, remove the timestamp file
        if [ -f "$REPEAT_ALERT_FILE" ]; then
            rm -f "$REPEAT_ALERT_FILE"
            log_message "Removed alert timestamp file as disk usage is no longer critical"
        fi
    fi
}

# Execute main function with any passed arguments
main "$@"
