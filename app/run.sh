#!/usr/bin/env bash
# ThemerUltimate picker: toggle the window (start the daemon on first use).
#   run.sh [open|toggle|close]   (default toggle)
export PATH="$HOME/.local/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/${USER:-$(id -un)}/bin:/run/current-system/sw/bin:$PATH"
export QT_QUICK_CONTROLS_STYLE=Basic
act="${1:-toggle}"
if quickshell ipc -c themer-ultimate call themer "$act" 2>/dev/null; then exit 0; fi
[ "$act" = close ] && exit 0
cd "$HOME" && exec quickshell -c themer-ultimate --no-duplicate --daemonize
