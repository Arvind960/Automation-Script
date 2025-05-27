#!/bin/bash

# FTP File Transfer Failure Handling Script
# This script monitors FTP transfers, detects failures, and implements retry mechanisms
# Author: Amazon Q
# Date: 2025-05-27

# Configuration variables
MAX_RETRIES=3
RETRY_DELAY=60  # seconds
LOG_FILE="/var/log/ftp_transfer.log"
NOTIFICATION_EMAIL="admin@example.com"
FTP_SERVER="ftp.example.com"
FTP_USER="username"
FTP_PASS="password"
FTP_REMOTE_DIR="/remote/directory"
LOCAL_DIR="/local/directory"
FAILED_TRANSFERS_FILE="/tmp/failed_transfers.txt"

# Create log file if it doesn't exist
touch $LOG_FILE

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOG_FILE
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

send_notification() {
    local subject="$1"
    local message="$2"
    echo -e "$message" | mail -s "$subject" $NOTIFICATION_EMAIL
    log_message "Notification sent to $NOTIFICATION_EMAIL"
}

check_dependencies() {
    for cmd in lftp mail; do
        if ! command -v $cmd &> /dev/null; then
            log_message "ERROR: Required command '$cmd' not found. Please install it."
            exit 1
        fi
    done
}

# Function to attempt FTP transfer with retries
transfer_file() {
    local file="$1"
    local retry_count=0
    local success=false

    while [ $retry_count -lt $MAX_RETRIES ] && [ "$success" = false ]; do
        log_message "Attempting to transfer file: $file (Attempt $(($retry_count + 1))/$MAX_RETRIES)"
        
        # Using lftp for more reliable transfers
        if lftp -c "open -u $FTP_USER,$FTP_PASS $FTP_SERVER; cd $FTP_REMOTE_DIR; put $LOCAL_DIR/$file"; then
            log_message "SUCCESS: File $file transferred successfully"
            success=true
        else
            retry_count=$((retry_count + 1))
            log_message "FAILED: File $file transfer failed (Attempt $retry_count/$MAX_RETRIES)"
            
            if [ $retry_count -lt $MAX_RETRIES ]; then
                log_message "Waiting $RETRY_DELAY seconds before retry..."
                sleep $RETRY_DELAY
            fi
        fi
    done

    if [ "$success" = false ]; then
        log_message "ERROR: File $file failed after $MAX_RETRIES attempts"
        echo "$file" >> $FAILED_TRANSFERS_FILE
        return 1
    fi
    
    return 0
}

# Function to process all files in the directory
process_directory() {
    local files_processed=0
    local files_failed=0
    
    # Clear the failed transfers file
    > $FAILED_TRANSFERS_FILE
    
    log_message "Starting FTP transfer process for files in $LOCAL_DIR"
    
    for file in "$LOCAL_DIR"/*; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            if transfer_file "$filename"; then
                files_processed=$((files_processed + 1))
            else
                files_failed=$((files_failed + 1))
            fi
        fi
    done
    
    log_message "FTP transfer process completed. Processed: $files_processed, Failed: $files_failed"
    
    # Handle failed transfers
    if [ $files_failed -gt 0 ]; then
        local failed_files=$(cat $FAILED_TRANSFERS_FILE | tr '\n' ', ' | sed 's/,$//')
        send_notification "FTP Transfer Failures" "FTP transfer process completed with $files_failed failures.\n\nFailed files: $failed_files\n\nPlease check the log file at $LOG_FILE for more details."
        return 1
    fi
    
    return 0
}

# Function to retry previously failed transfers
retry_failed_transfers() {
    if [ ! -f $FAILED_TRANSFERS_FILE ] || [ ! -s $FAILED_TRANSFERS_FILE ]; then
        log_message "No failed transfers to retry"
        return 0
    fi
    
    log_message "Retrying previously failed transfers"
    local retry_success=0
    local still_failed=0
    local new_failed_file="/tmp/still_failed_transfers.txt"
    > $new_failed_file
    
    while IFS= read -r file; do
        log_message "Retrying transfer for file: $file"
        if transfer_file "$file"; then
            retry_success=$((retry_success + 1))
        else
            still_failed=$((still_failed + 1))
            echo "$file" >> $new_failed_file
        fi
    done < $FAILED_TRANSFERS_FILE
    
    # Update the failed transfers file
    mv $new_failed_file $FAILED_TRANSFERS_FILE
    
    log_message "Retry process completed. Successfully retried: $retry_success, Still failed: $still_failed"
    
    if [ $still_failed -gt 0 ]; then
        local failed_files=$(cat $FAILED_TRANSFERS_FILE | tr '\n' ', ' | sed 's/,$//')
        send_notification "FTP Retry Failures" "FTP retry process completed with $still_failed persistent failures.\n\nFailed files: $failed_files\n\nManual intervention may be required."
        return 1
    fi
    
    return 0
}

# Main execution
main() {
    log_message "=== FTP File Transfer Script Started ==="
    
    # Check for required dependencies
    check_dependencies
    
    # Process all files in the directory
    process_directory
    
    # If command line argument "retry" is provided, retry failed transfers
    if [ "$1" = "retry" ]; then
        retry_failed_transfers
    fi
    
    log_message "=== FTP File Transfer Script Completed ==="
}

# Execute main function with all command line arguments
main "$@"
