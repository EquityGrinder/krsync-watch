# krsync-bidirectional: Two-Way Event-Driven Sync (Windows ↔ Kubernetes Pod)

## Overview

`krsync-bidirectional` is a robust Bash-based solution for **real-time, bidirectional file sync** between a Windows 11 folder and a directory in a Kubernetes pod. It leverages event watchers on both sides—`fswatch` (Windows) and `inotifywait` (Pod)—to mirror changes instantly without manual intervention.

- **One script to rule them all:** Run on your Windows machine to manage two-way sync in parallel.
- **Event-driven:** Changes in either location are synced live, not polled.
- **Minimal, cross-platform dependencies:** Only Bash, rsync, tar, kubectl, fswatch (npm), inotifywait (Pod).
- **Built-in exclusions:** Smart filtering for `.git`, `node_modules`, and logs; customizable via config or args.
- **Flexible:** Fully configurable paths, namespace, pod, exclude file, logging.
- **Open source & extensible.**

---

## Features
- **True bidirectional file sync:** Keeps two dirs in perfect real-time parity.
- **Configurable source/destination paths** for both local and pod.
- **Built-in & custom file exclusions** (`node_modules`, `.git`, `*.log` by default).
- **Automatic dependency and environment checks** (with error feedback).
- **Clear logging:** Optional logfile.
- **Extensible design:** Add your own exclude files, polling fallback, log rotations.

---

## Requirements
### Windows Side
- [Git Bash](https://gitforwindows.org/)
- [npm](https://nodejs.org/) (for fswatch)
- [rsync](https://www.msys2.org/), [tar](https://www.gnu.org/software/tar/), [kubectl](https://kubernetes.io/docs/tasks/tools/)

### Kubernetes Pod
- bash
- rsync
- tar
- [inotifywait (inotify-tools)](https://github.com/inotify-tools/inotify-tools) 

---

## Installation

### 1. Windows
- Install dependencies:
  ```sh
  npm install -g fswatch
  # For rsync, tar: Use MSYS2/Cygwin/WSL as needed
  # For kubectl: https://kubernetes.io/docs/tasks/tools/
  ```
  Confirm all tools are available in your shell.

### 2. Pod
- Confirm tools in your pod:
  ```sh
  kubectl exec <pod> -- bash -c "which rsync && which tar && which inotifywait"
  # If missing, install via apt/your distro
  # Example for Debian/Ubuntu pod:
  apt update && apt install -y rsync tar inotify-tools
  ```

---

## Usage

### Bidirectional Sync from Windows
Run `krsync-bidirectional.sh` from your Win11 project directory:

```sh
./krsync-bidirectional.sh <pod-name> [namespace] [local-dir] [pod-dir] [exclude-file] [logfile]
```
**Arguments:**
- `pod-name`: Name of your pod (required)
- `namespace`: Kubernetes namespace (default: `default`)
- `local-dir`: Path to local directory to sync (default: current directory)
- `pod-dir`: Path in pod to sync (default: `/home/user/projects`)
- `exclude-file`: Optional rsync exclude file (like `.krsyncignore`)
- `logfile`: Optional path for sync logs

**Example:**
```sh
./krsync-bidirectional.sh mypod dev ./src /home/appuser/app .krsyncignore krsync.log
```
This watches both local and pod directories for changes, syncing files in both directions using tar+rsync.

---

### Pod Event Watch Script (to be run in pod)
For advanced use, you may want a helper script for the pod to push events back:

Save this as `pod-sync-event.sh` in your pod (or your repo):
```bash
#!/bin/bash
# Usage: ./pod-sync-event.sh <watched-dir>
WATCH_DIR="${1:-/home/user/projects}"
EXCLUDES=(--exclude 'node_modules' --exclude '.git' --exclude '*.log')
while inotifywait -r -e modify,create,delete "$WATCH_DIR"; do
  tar --exclude='node_modules' --exclude='.git' --exclude='*.log' -cf /tmp/podsync.tar -C "$WATCH_DIR" .
  # You can choose to kubectl cp this file out or trigger your bidirectional sync script to fetch it
  rm -f /tmp/podsync.tar
done
```
You could use this inside your pod, for special cases (in a CI pipeline or as part of complex event logic).

---

## Built-in Rsync Exclusions
Defaults:
- `node_modules`
- `.git`
- `*.log`
You may provide more via an exclude file passed as argument.

---

## Troubleshooting & FAQ
- "Tool not found"? Make sure fswatch/rsync/tar/kubectl are in your PATH (Win) and rsync, tar, inotifywait (Pod).
- "Permission denied"? Check pod dir/owner; Win user must own local.
- "Sync loop or event spam"? Tweak exclude file, limit event types, or add debouncing. Avoid syncing generated/lock files.
- "Filename errors"? Avoid Windows-reserved characters (tar handles most unicode/utf-8).
- "Inotifywait not working"? Check pod OS/package manager. Use polling if truly needed.
- "Large files slow to sync"? Try increasing sync intervals or exclude large cache/build dirs.

---

## Advanced Configuration
- Supply your own `.krsyncignore` to exclude extra files/dirs.
- Use logfiles for audit/debugging by passing a file path as last arg.
- Tweak event watcher lines in scripts for custom event types.

---

## License
MIT

## Credits
Built with Bash, npm, fswatch, rsync, tar, kubectl, and the Kubernetes + UNIX OS communities.