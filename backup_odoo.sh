#!/bin/bash

# Variables
BACKUP_DIR="/home/ubuntu/odoo_backups"
DB_USER="odoo"
DB_HOST="localhost"
DB_PORT="5432"
DATE=$(date +"%Y-%m-%d")
LOG_FILE="/home/ubuntu/odoo_backups/backup.log"

# Create the backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Get the list of databases
DB_LIST=$(psql -h $DB_HOST -U $DB_USER -d postgres -t -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres');")

# Backup each database
for DB in $DB_LIST; do
    BACKUP_FILE="$BACKUP_DIR/${DB}_$DATE.sql.gz"
    echo "Backing up database $DB to $BACKUP_FILE" | tee -a "$LOG_FILE"
    pg_dump -h $DB_HOST -U $DB_USER -p $DB_PORT -d $DB | gzip > "$BACKUP_FILE"

    if [[ $? -eq 0 ]]; then
        echo "Backup of $DB completed successfully." | tee -a "$LOG_FILE"
    else
        echo "Backup of $DB failed!" | tee -a "$LOG_FILE"
    fi
done

echo "Backup process completed on $(date)" | tee -a "$LOG_FILE"
