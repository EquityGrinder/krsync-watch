# krsync-watch: Event-Based Bidirectional Sync (Win11 ↔ k8s Pod)

## Overview

**krsync-watch** is a pair of simple Bash scripts that enable seamless, event-driven file synchronization between a local Windows 11 machine (using Git Bash) and a directory within a Kubernetes pod. Changes are synced instantly — perfect for live development, CI/CD, or collaborative scenarios where directories must stay up to date with minimal overhead.

- **Event-based (real-time) sync:** Scripts use `fswatch` and standard Bash utilities to react instantly to file changes.
- **Bidirectional:** Sync either from Win11 to k8s pod, or the reverse.
- **Minimal dependencies:** Only standard Bash, rsync, tar, kubectl, and fswatch (via npm).
- **Exclusion filters built-in:** Sensible defaults for `.git`, `node_modules`, logs (easy to customize)
- **Extensible:** All paths, exclusion filters, and intervals are easily configurable.

---

## Features
- Fast, event-driven directory sync
- Built for cross-platform (Win11 + k8s)
- Built-in exclusion of junk directories and files
- Fully configurable sync source/target/destination
- Works with standard bash, rsync, tar, kubectl
- Simple usage and clear feedback for errors

---

## Requirements

### On Windows 11:
- [Git Bash](https://gitforwindows.org/) (recommended)
- [npm](https://nodejs.org/) for installing fswatch
- [rsync](https://www.msys2.org/) (from MSYS2, Cygwin, or WSL if not already present)
- [tar](https://www.gnu.org/software/tar/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (installed and configured)

### On Kubernetes Pod:
- bash
- rsync
- tar
- Optionally: [inotify-tools](https://github.com/inotify-tools/inotify-tools) for inotifywait if bidirectional sync is needed

---

## Installation
1. **Install fswatch for event watching:**
   ```sh
   npm install -g fswatch
   ```
2. **Install rsync:**
   - On Windows: Use [MSYS2](https://www.msys2.org/), [Cygwin](https://www.cygwin.com/), or [WSL](https://docs.microsoft.com/en-us/windows/wsl/).
   - On Linux: Usually already installed, else `sudo apt install rsync`.
3. **Ensure kubectl is installed and configured.**
4. **Confirm tar is available (should be standard on all UNIX-like systems and in MSYS2/Cygwin/WSL).**

---

## Usage

### 1. Win11 → k8s Pod (`win-to-k8s.sh`)

**Syncs local directory to a directory inside your Kubernetes pod whenever a change is detected.**

__Basic usage:__
```sh
./win-to-k8s.sh <pod-name> [namespace] [local-source-dir] [pod-target-dir]
```
- `pod-name`: Name of the target pod.
- `namespace`: (optional) Kubernetes namespace (default: `default`).
- `local-source-dir`: (optional) Directory to watch locally (default: current directory).
- `pod-target-dir`: (optional) Directory in pod to sync to (default: `/home/user/projects`).

__Example:__
```sh
./win-to-k8s.sh mypod dev ./src /home/devuser/app
```

### 2. k8s Pod → Win11 (`k8s-to-win.sh`)

**Syncs pod directory to local Win11 directory on file change using inotify (if available), or by polling as fallback.**

__Basic usage:__
```sh
./k8s-to-win.sh <pod-name> [namespace] [pod-source-dir] [local-target-dir]
```
- `pod-name`: Name of your pod
- `namespace`: (optional) Kubernetes namespace (default: `default`)
- `pod-source-dir`: (optional) Directory inside the pod to watch (default: `/home/user/projects`)
- `local-target-dir`: (optional) Local directory to sync to (default: current directory)

__Example:__
```sh
./k8s-to-win.sh mypod dev /home/devuser/app ./synced
```


---

## Built-in Rsync Exclusions

To avoid syncing unnecessary files, both scripts use these default exclusions:
- `node_modules`
- `.git`
- `*.log`
You can add more in the script via the `EXCLUDES` section.

---

## Troubleshooting & FAQ

### Common issues:
- **Tool not found?** Ensure `fswatch`, `rsync`, `tar`, and `kubectl` are in your PATH.
- **Permission denied in pod?** User running rsync/tar in the pod must own the target directory.
- **rsync errors?** Check permissions, and if sync direction/paths are correct.
- **kubectl errors?** Make sure context and pod name/namespace are correct. Test with `kubectl exec` manually.
- **Event spam?** fswatch (or inotifywait) may trigger multiple syncs for single edits. Use exclusion filters, or increase debounce interval if necessary.
- **No rsync on Windows?** Install via MSYS2, Cygwin, or WSL. Confirm in Git Bash: `which rsync`
- **Filename/encoding errors?** tar handles Unicode safely; avoid rare Windows-specific reserved characters in file names.
- **Special files/symlinks:** These may not sync as expected on cross-platform. You can add specific rsync options to handle or ignore links.

### Advanced:
- **Add exclusions:** In scripts, update the `EXCLUDES` array and rsync argument.
- **Dry-run:** Adapt rsync command with `--dry-run` for testing.
- **Polling fallback:** If event watcher not available, loop with sleep interval and run rsync/tar each period.

---

## License
MIT

## Credits
Built with Bash, npm, fswatch, rsync, kubectl, tar, Kubernetes.
Thanks to the open source UNIX and k8s communities for stable tools.