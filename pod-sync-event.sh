#!/bin/bash
# pod-sync-event.sh: Watch a directory in the pod via inotifywait and create a tar archive for syncing
# Usage: ./pod-sync-event.sh [watched-dir]
# --- Load .env.pod if present ---
if [ -f .env.pod ]; then
  set -a
  source .env.pod
  set +a
fi
WATCH_DIR="${1:-$WATCH_DIR}"
EXCLUDES=()
IFS=',' read -ra excs <<< "$EXCLUDE_PATTERNS"
for excl in "${excs[@]}"; do
  EXCLUDES+=(--exclude "$excl")
done

while inotifywait -r -e modify,create,delete "$WATCH_DIR"; do
  echo "[$(date)] Change detected in $WATCH_DIR. Packing for sync..."
  tar --exclude='node_modules' --exclude='.git' --exclude='*.log' -cf /tmp/podsync.tar -C "$WATCH_DIR" .
  echo "Packed /tmp/podsync.tar for sync. (remove or transfer as needed)"
  rm -f /tmp/podsync.tar
  echo "Temp archive removed."
done
