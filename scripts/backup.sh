#!/bin/bash
set -e

BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="openspecimen_backup_${TIMESTAMP}"

mkdir -p ${BACKUP_DIR}

echo "=== Backup OpenSpecimen ${TIMESTAMP} ==="

# Backup MySQL
echo "Backing up MySQL..."
docker exec openspecimen-mysql mysqldump -u root -prootpass openspecimen > ${BACKUP_DIR}/${BACKUP_NAME}_db.sql

# Backup config
echo "Backing up config..."
tar -czf ${BACKUP_DIR}/${BACKUP_NAME}_config.tar.gz config/

# Backup data
echo "Backing up data..."
tar -czf ${BACKUP_DIR}/${BACKUP_NAME}_data.tar.gz volumes/openspecimen_data/ volumes/openspecimen_plugins/

echo "=== Backup completado ==="
echo "Archivos en: ${BACKUP_DIR}/"
ls -la ${BACKUP_DIR}/${BACKUP_NAME}*
