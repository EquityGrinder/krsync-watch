#!/bin/bash
# win-to-k8s.sh: Watch a local directory and sync changes to a k8s pod in real-time

set -e

POD="$1"
NS="${2:-default}"
LOCAL_SRC="${3:-$(pwd)}"
POD_DEST="${4:-/home/user/projects}"

EXCLUDES=(--exclude 'node_modules' --exclude '.git' --exclude '*.log')

usage() {
  echo "Usage: $0 <pod-name> [namespace] [local-source-dir] [pod-target-dir]"
  echo "- pod-name: Target k8s pod name"
  echo "- namespace: (optional) Kubernetes namespace [default: default]"
  echo "- local-source-dir: (optional) Directory to watch [default: current directory]"
  echo "- pod-target-dir: (optional) Destination in pod [default: /home/user/projects]"
  exit 1
}

if [[ -z "$POD" ]]; then
  usage
fi

if ! command -v fswatch >/dev/null; then
  echo "Error: fswatch not found. Install with: npm install -g fswatch"
  exit 2
fi
if ! command -v rsync >/dev/null; then
  echo "Error: rsync not found. Install via MSYS2, Cygwin, or WSL, then verify in Git Bash: which rsync"
  exit 2
fi
if ! command -v tar >/dev/null; then
  echo "Error: tar not found. Confirm tar is in your PATH."
  exit 2
fi
if ! command -v kubectl >/dev/null; then
  echo "Error: kubectl not found. Install and configure kubectl."
  exit 2
fi

# Compose exclusions for rsync
EXCL_ARGS="${EXCLUDES[@]}"


echo "🔄 Watching $LOCAL_SRC for changes → pod $POD namespace $NS destination $POD_DEST"

fswatch -o "$LOCAL_SRC" | while read; do
  echo "$(date): Change detected in $LOCAL_SRC. Syncing to pod $POD:$POD_DEST ..."
  tar --exclude='node_modules' --exclude='.git' --exclude='*.log' -cf - -C "$LOCAL_SRC" . | 
    kubectl exec -i -n "$NS" "$POD" -- bash -c "
      mkdir -p /tmp/krsync && 
      tar -xf - -C /tmp/krsync && 
      rsync -avz --delete ${EXCL_ARGS} /tmp/krsync/ '$POD_DEST'/ && 
      rm -rf /tmp/krsync"
  echo "✓ Synced!"
done
