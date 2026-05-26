#!/usr/bin/env bash
# Daily Postgres backup → Hetzner Object Storage.
# Install on server: chmod +x backup.sh, then add to root crontab:
#   0 3 * * * /opt/twenty/backup.sh >> /var/log/twenty-backup.log 2>&1
#
# Requires: docker, awscli (`apt install awscli`), and AWS_* env from /opt/twenty/.env.backup

set -euo pipefail

# Load backup credentials (separate Hetzner key — use a different bucket from app uploads if you can)
# .env.backup format:
#   AWS_ACCESS_KEY_ID=...
#   AWS_SECRET_ACCESS_KEY=...
#   AWS_ENDPOINT_URL=https://fsn1.your-objectstorage.com
#   BACKUP_BUCKET=twenty-backups
set -a
source /opt/twenty/.env.backup
set +a

STAMP=$(date +%Y%m%d_%H%M%S)
DUMP_FILE="/tmp/twenty_${STAMP}.sql.gz"

# pg_dump from inside the running db container
docker exec -t twenty-db-1 pg_dump -U postgres default | gzip > "$DUMP_FILE"

aws --endpoint-url "$AWS_ENDPOINT_URL" s3 cp "$DUMP_FILE" "s3://${BACKUP_BUCKET}/postgres/twenty_${STAMP}.sql.gz"

rm "$DUMP_FILE"

# Prune backups older than 30 days
CUTOFF=$(date -d '30 days ago' +%Y-%m-%d)
aws --endpoint-url "$AWS_ENDPOINT_URL" s3 ls "s3://${BACKUP_BUCKET}/postgres/" \
  | awk -v cutoff="$CUTOFF" '$1 < cutoff {print $4}' \
  | while read -r f; do
      aws --endpoint-url "$AWS_ENDPOINT_URL" s3 rm "s3://${BACKUP_BUCKET}/postgres/${f}"
    done

echo "Backup complete: twenty_${STAMP}.sql.gz"
