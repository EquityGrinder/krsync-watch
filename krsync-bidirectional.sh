#!/bin/bash
# krsync-bidirectional.sh: Bidirectional event-driven sync (Win11 <-> k8s pod)
# Uses fswatch locally and inotifywait (via kubectl exec) in the pod.

set -e

# --- Config ---
default_local="$(pwd)"
default_pod="/home/user/projects"
default_ns="default"
default_excludes=(--exclude 'node_modules' --exclude '.git' --exclude '*.log')

# --- Load .env if present ---
if [ -f .env ]; then
  set -a
  source .env
  set +a
fi
# --- Args override .env ---
POD="${1:-$POD_NAME}"
NS="${2:-$NAMESPACE}"
LOCAL_DIR="${3:-$LOCAL_DIR}"
POD_DIR="${4:-$POD_DIR}"
EXCLUDE_FILE="${5:-$EXCLUDE_FILE}"
LOGFILE="${6:-$LOGFILE}"

usage() {
  echo "Usage: $0 <pod-name> [namespace] [local-dir] [pod-dir] [exclude-file] [logfile]"
  echo "  pod-name      : K8s pod to sync with"
  echo "  namespace     : (optional) Kubernetes namespace [default: $default_ns]"
  echo "  local-dir     : (optional) Local directory to sync [default: cwd]"
  echo "  pod-dir       : (optional) Directory in pod [default: $default_pod]"
  echo "  exclude-file  : (optional) Rsync exclude file (.krsyncignore)"
  echo "  logfile       : (optional) File to write logs."
  exit 1
}

[[ -z "$POD" ]] && usage

# --- Dependency Checks ---
for dep in fswatch rsync tar kubectl; do
  if ! command -v "$dep" > /dev/null; then
    echo "Error: $dep not found. See README for install instructions." | tee -a "$LOGFILE"
    exit 2
  fi
done

# Optional: check inotifywait in pod
if ! kubectl exec -n "$NS" "$POD" -- command -v inotifywait >/dev/null 2>&1; then
  echo "Error: inotifywait not installed in pod. Install via 'apt install inotify-tools'." | tee -a "$LOGFILE"
  exit 2
fi

# --- Exclusions ---
EXCL_ARGS=("${default_excludes[@]}")
if [[ -n "$EXCLUDE_FILE" && -f "$EXCLUDE_FILE" ]]; then
  EXCL_ARGS+=("--exclude-from=$EXCLUDE_FILE")
fi

# --- Functions ---
sync_to_pod() {
  echo "[$(date)] Local event: Syncing $LOCAL_DIR → pod $POD:$POD_DIR" | tee -a "$LOGFILE"
  tar --exclude='node_modules' --exclude='.git' --exclude='*.log' -cf - -C "$LOCAL_DIR" . |
    kubectl exec -i -n "$NS" "$POD" -- bash -c "
      mkdir -p /tmp/krsync && 
      tar -xf - -C /tmp/krsync && 
      rsync -avz --delete ${EXCL_ARGS[@]} /tmp/krsync/ '$POD_DIR'/ && 
      rm -rf /tmp/krsync"
  echo "✓ Synced local → pod" | tee -a "$LOGFILE"
}

sync_to_local() {
  echo "[$(date)] Pod event: Syncing $POD:$POD_DIR → $LOCAL_DIR" | tee -a "$LOGFILE"
  kubectl exec -i -n "$NS" "$POD" -- tar --exclude='node_modules' --exclude='.git' --exclude='*.log' -cf - -C "$POD_DIR" . |
    tar -xf - -C "$LOCAL_DIR"
  rsync -avz --delete ${EXCL_ARGS[@]} "$LOCAL_DIR"/ "$LOCAL_DIR"/
  echo "✓ Synced pod → local" | tee -a "$LOGFILE"
}

# --- Bidirectional Watchers ---
echo "Starting bidirectional sync: $LOCAL_DIR <--> $POD:$POD_DIR (namespace: $NS)" | tee -a "$LOGFILE"
echo "Exclusions: ${EXCL_ARGS[@]}" | tee -a "$LOGFILE"

# --- fswatch local (push changes to pod) ---
fswatch -o "$LOCAL_DIR" | while read; do sync_to_pod; done &
FSWATCH_PID=$!

# --- inotifywait remote (pull changes from pod) ---
kubectl exec -n "$NS" "$POD" -- bash -c "inotifywait -m -r -e modify,create,delete '$POD_DIR'" | while read; do sync_to_local; done &
INOTIFY_PID=$!

# --- Wait for either watcher to exit ---
trap "kill $FSWATCH_PID $INOTIFY_PID" EXIT
wait