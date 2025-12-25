#!/bin/bash
set -euo pipefail

# Where your backups live (must match your backup script)
BACKUP_DIR="/media/meitu001/Data/backup"

# Restore only backups matching this prefix (safety)
PREFIX="cvat_cvat"

# Pass --force to overwrite existing data in a volume
FORCE=false
if [[ "${1:-}" == "--force" ]]; then
  FORCE=true
fi

shopt -s nullglob

BACKUPS=( "${BACKUP_DIR}/${PREFIX}"*_backup.tar.gz )

if (( ${#BACKUPS[@]} == 0 )); then
  echo "No backups found in ${BACKUP_DIR} matching ${PREFIX}*_backup.tar.gz"
  exit 1
fi

echo "Found ${#BACKUPS[@]} backup file(s)."

for TARFILE in "${BACKUPS[@]}"; do
  BASENAME="$(basename "$TARFILE")"
  # Strip suffix "_backup.tar.gz" to get the volume name
  VOLUME="${BASENAME%_backup.tar.gz}"

  echo "----------------------------------------"
  echo "Restoring backup: $TARFILE"
  echo "Target volume:    $VOLUME"

  # Ensure the volume exists
  if ! docker volume inspect "$VOLUME" >/dev/null 2>&1; then
    echo "Volume $VOLUME does not exist; creating..."
    docker volume create "$VOLUME" >/dev/null
  fi

  # Check whether the volume is empty
  # (We consider it "empty" if it has no files at all.)
  if docker run --rm -v "${VOLUME}:/volume" alpine sh -c 'ls -A /volume >/dev/null 2>&1 && test -n "$(ls -A /volume 2>/dev/null)"'; then
    if [[ "$FORCE" == false ]]; then
      echo "ERROR: Volume $VOLUME is not empty. Refusing to overwrite."
      echo "       Re-run with --force to overwrite existing contents."
      exit 2
    else
      echo "WARNING: Volume $VOLUME is not empty; --force specified."
      echo "         Clearing existing contents..."
      docker run --rm -v "${VOLUME}:/volume" alpine sh -c 'rm -rf /volume/* /volume/.[!.]* /volume/..?* 2>/dev/null || true'
    fi
  else
    echo "Volume $VOLUME appears empty; proceeding."
  fi

  # Extract the tarball into the volume
  docker run --rm \
    -v "${VOLUME}:/volume" \
    -v "${BACKUP_DIR}:/backup" \
    alpine sh -c "tar xzf \"/backup/${BASENAME}\" -C /volume"

  echo "Restore complete for $VOLUME"
done

echo "----------------------------------------"
echo "All restores complete."
echo "Tip: verify with: docker volume ls | grep ${PREFIX}"
