#!/bin/bash
# k8s-to-win.sh: Watch a directory inside a k8s pod, sync changes to local Win11 directory in real-time

set -e

POD="$1"
NS="${2:-default}"
POD_SRC="${3:-/home/user/projects}"
LOCAL_DEST="${4:-$(pwd)}"

EXCLUDES=(--exclude 'node_modules' --exclude '.git' --exclude '*.log')

usage() {
  echo "Usage: $0 <pod-name> [namespace] [pod-source-dir] [local-target-dir]"
  echo "- pod-name: Pod to sync from"
  echo "- namespace: (optional) Kubernetes namespace [default: default]"
  echo "- pod-source-dir: (optional) Source in pod [default: /home/user/projects]"
  echo "- local-target-dir: (optional) Local destination [default: current directory]"
  exit 1
}

if [[ -z "$POD" ]]; then
  usage
fi

if ! command -v kubectl >/dev/null; then
  echo "Error: kubectl not found. Install and configure kubectl."
  exit 2
fi
if ! command -v tar >/dev/null; then
  echo "Error: tar not found. Confirm tar is in your PATH."
  exit 2
fi
if ! command -v rsync >/dev/null; then
  echo "Error: rsync not found. Install via MSYS2, Cygwin, or WSL."
  exit 2
fi

EXCL_ARGS="${EXCLUDES[@]}"

# Check for inotifywait in pod, fallback to polling if missing
if kubectl exec -n "$NS" "$POD" -- command -v inotifywait >/dev/null 2>&1; then
  echo "🔄 Using inotifywait in pod for real-time events. Watching $POD_SRC in pod $POD namespace $NS → $LOCAL_DEST"
  kubectl exec -n "$NS" "$POD" -- bash -c "inotifywait -m -r -e modify,create,delete '$POD_SRC'" | while read; do
    echo "$(date): Change detected in $POD_SRC (pod $POD). Syncing to $LOCAL_DEST ..."
    kubectl exec -i -n "$NS" "$POD" -- tar --exclude='node_modules' --exclude='.git' --exclude='*.log' -cf - -C "$POD_SRC" . | 
      tar -xf - -C "$LOCAL_DEST"
    rsync -avz --delete ${EXCL_ARGS} "$LOCAL_DEST"/ "$LOCAL_DEST"/
    echo "✓ Synced!"
  done
else
  echo "⚠️ 'inotifywait' not found in pod. Falling back to polling every 10 seconds."
  while sleep 10; do
    echo "$(date): Polling pod $POD:$POD_SRC ..."
    kubectl exec -i -n "$NS" "$POD" -- tar --exclude='node_modules' --exclude='.git' --exclude='*.log' -cf - -C "$POD_SRC" . | 
      tar -xf - -C "$LOCAL_DEST"
    rsync -avz --delete ${EXCL_ARGS} "$LOCAL_DEST"/ "$LOCAL_DEST"/
    echo "✓ Synced!"
  done
fi
