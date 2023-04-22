#!/usr/bin/env bash
set -eo pipefail

# Create mount directory for service
mkdir -p $MNT_DIR

echo "Mounting GCS Fuse."
if [ -z "$RUN_SEAFOWL_READ_ONLY" ]; then
gcsfuse --debug_gcs --debug_fuse $BUCKET $MNT_DIR
else
gcsfuse --debug_gcs --debug_fuse -o ro $BUCKET $MNT_DIR
fi
echo "Mounting completed."

exec env SEAFOWL__FRONTEND__HTTP_BIND_PORT=$PORT ./seafowl -c /app/config/seafowl.toml &

# Exit immediately when one of the background processes terminate.
wait -n