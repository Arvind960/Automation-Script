# Automation-Script

A collection of automation scripts for handling common operational tasks.

## FTP Failure Recovery Script

This script monitors FTP transfers, detects failures, and implements retry mechanisms to ensure reliable file transfers.

### Features

- Automatic retry of failed FTP transfers
- Configurable retry count and delay
- Detailed logging of all transfer attempts
- Email notifications for persistent failures
- Support for manual retry of previously failed transfers

### Requirements

- `lftp` - Enhanced FTP client with more reliable transfer capabilities
- `mail` - Command-line email utility for notifications

### Configuration

Edit the following variables at the top of the script to match your environment:

```bash
MAX_RETRIES=3               # Maximum number of retry attempts
RETRY_DELAY=60              # Delay between retries in seconds
LOG_FILE="/var/log/ftp_transfer.log"  # Path to log file
NOTIFICATION_EMAIL="admin@example.com"  # Email for failure notifications
FTP_SERVER="ftp.example.com"  # FTP server address
FTP_USER="username"         # FTP username
FTP_PASS="password"         # FTP password
FTP_REMOTE_DIR="/remote/directory"  # Remote directory on FTP server
LOCAL_DIR="/local/directory"  # Local directory containing files to transfer
```

### Usage

#### Basic Usage

```bash
./ftp_recovery.sh
```

This will attempt to transfer all files in the configured local directory to the FTP server.

#### Retry Failed Transfers

```bash
./ftp_recovery.sh retry
```

This will attempt to retry any previously failed transfers.

### Scheduling with Cron

Add the script to your crontab to run automatically:

```
# Run FTP transfer every hour
0 * * * * /path/to/ftp_recovery.sh

# Retry failed transfers every 4 hours
0 */4 * * * /path/to/ftp_recovery.sh retry
```

### Security Note

This script contains FTP credentials. Consider using environment variables or a secure credential store instead of hardcoding credentials in the script.
