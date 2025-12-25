#!/bin/bash

# Directory where you want to store your backups
BACKUP_DIR="/media/meitu001/Data/backup"

# List all volumes that start with 'cvat_cvat'
for VOLUME in $(docker volume ls --filter "name=cvat_cvat" -q); do
    # Backup each volume to a .tar.gz file
    echo "Backing up volume $VOLUME..."
    docker run --rm -v $VOLUME:/volume -v $BACKUP_DIR:/backup alpine \
        tar czf /backup/${VOLUME}_backup.tar.gz -C /volume .
done

echo "Backup complete."
