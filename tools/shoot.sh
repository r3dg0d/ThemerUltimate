#!/usr/bin/env bash
# Screenshot every themed surface for one theme into previews/<theme>/ (used for the README; Vincent's rice).
#   tools/shoot.sh <theme-id> [shot ...]     runs on workspace 2 (must be empty), returns to the previous one.
# Private hub pages (weather, network) are never shot.
set -u
export PATH="$HOME/.local/bin:/run/current-system/sw/bin:$PATH" QT_QUICK_CONTROLS_STYLE=Basic
here="$(cd "$(dirname "$0")/.." && pwd)"; theme="$1"; shift
out="$here/previews/$theme"; mkdir -p "$out"
q="$HOME/.config/quickshell"
prev_ws="$(niri msg -j workspaces | python3 -c 'import json,sys; print(next(w["idx"] for w in json.load(sys.stdin) if w["is_focused"]))')"
niri msg action focus-workspace 2; sleep 0.5
# Only ever capture workspace 2 holding nothing but our own windows; anything else is discarded, never saved.
on2() { niri msg action focus-workspace 2; sleep 0.35; }
safe() { niri msg -j workspaces | python3 -c '
import json, sys, subprocess
ws = json.load(sys.stdin); f = next(w for w in ws if w["is_focused"])
if f["idx"] != 2: sys.exit(1)
wins = json.loads(subprocess.run(["niri", "msg", "-j", "windows"], capture_output=True, text=True).stdout)
ok = lambda t: t == "ThemerShot" or t.startswith("Galaxy") or t == "ThemerUltimate" or t == "OBS picker"
bad = [w["title"] for w in wins if w["workspace_id"] == f["id"] and not ok(w["title"] or "")]
sys.exit(2 if bad else 0)'; }
snap() {
  sleep "${2:-2.2}"
  for try in 1 2 3; do
    if safe; then grim "$out/$1.png" && echo "  $out/$1.png"; return 0; fi
    echo "  ($1: workspace 2 not clean/focused, retrying)"; on2; sleep 1
  done
  rm -f "$out/$1.png"; echo "  SKIPPED $1 (could not get a clean workspace 2)"; return 1
}
want() { [ -z "$SHOTS" ] || [[ " $SHOTS " == *" $1 "* ]]; }
SHOTS="$*"; set --

if want desktop || want ghostty || want fuzzel; then
  ghostty --gtk-single-instance=false --title=ThemerShot -e bash --noprofile --norc -c \
    'fastfetch --structure Title:Separator:OS:Kernel:Uptime:Packages:Shell:WM:Terminal:TerminalFont:CPU:GPU:Memory:Break:Colors; printf "\n\033[35m❯\033[0m themer-ultimate list\n"; themer-ultimate list; exec sleep 900' >/dev/null 2>&1 &
  gpid=$!; sleep 3
  want ghostty && snap ghostty 0.5
  fuzzel --search=galaxy >/dev/null 2>&1 & fpid=$!
  want fuzzel && snap fuzzel 1.2
  kill $fpid 2>/dev/null; sleep 0.3
  # combined: terminal + hub + power for the README
  if want desktop; then
    bash "$q/galaxy-hub/start.sh" updater; quickshell ipc -c galaxy-power call power open >/dev/null 2>&1
    snap desktop 2.5
    quickshell ipc -c galaxy-power call power close >/dev/null 2>&1; quickshell ipc -c galaxy-hub call hub close >/dev/null 2>&1
  fi
  kill $gpid 2>/dev/null; pkill -f 'title=ThemerShot' 2>/dev/null
fi
for p in updater storage audio constructs; do
  want hub-$p || continue
  on2
  quickshell ipc -c galaxy-hub call hub open $p >/dev/null 2>&1; snap hub-$p; quickshell ipc -c galaxy-hub call hub close >/dev/null 2>&1
done
if want media; then on2; quickshell ipc -c galaxy call galaxy open >/dev/null 2>&1; snap media; quickshell ipc -c galaxy call galaxy close >/dev/null 2>&1; fi
if want power; then on2; quickshell ipc -c galaxy-power call power open >/dev/null 2>&1; snap power; quickshell ipc -c galaxy-power call power close >/dev/null 2>&1; fi
if want clip; then on2; bash "$q/galaxy-clip/start.sh" >/dev/null 2>&1; quickshell ipc -c galaxy-clip call clip open >/dev/null 2>&1; snap clip; quickshell ipc -c galaxy-clip call clip close >/dev/null 2>&1; fi
if want emoji; then on2; bash "$q/galaxy-emoji/start.sh" >/dev/null 2>&1; quickshell ipc -c galaxy-emoji call emoji open >/dev/null 2>&1; snap emoji; quickshell ipc -c galaxy-emoji call emoji close >/dev/null 2>&1; fi
if want ai-media; then on2; quickshell ipc -c galaxy-ai-media call aimedia open >/dev/null 2>&1 || bash "$q/galaxy-ai-media/start.sh"; snap ai-media 3; quickshell ipc -c galaxy-ai-media call aimedia toggle >/dev/null 2>&1; fi
if want disk; then on2; quickshell ipc -c galaxy-disk call disk open >/dev/null 2>&1; snap disk 3; quickshell ipc -c galaxy-disk call disk close >/dev/null 2>&1; fi
if want vm; then on2; bash "$q/galaxy-vm/start.sh" all >/dev/null 2>&1; snap vm 3; quickshell ipc -c galaxy-vm call vm close all >/dev/null 2>&1; fi
if want deepfake; then
  on2
  dpid="$(quickshell list --all 2>/dev/null | awk '/Process ID/{p=$3} /deepfake\/shell.qml/{print p; exit}')"
  [ -n "$dpid" ] && { quickshell ipc --pid "$dpid" call deepfake open >/dev/null 2>&1; snap deepfake 3; quickshell ipc --pid "$dpid" call deepfake toggle >/dev/null 2>&1; }
fi
if want osd; then on2   # a real volume change (+5% then -5%: net zero) so action.py drives the OSD like a key press
  python3 "$q/system-osd/action.py" volume-up >/dev/null 2>&1; python3 "$q/system-osd/action.py" volume-down >/dev/null 2>&1
  snap osd-volume 0.6
  sleep 2; quickshell ipc -c keystroke-noise call noise showState on "typing sounds on" >/dev/null 2>&1
  snap osd-keys 0.6
fi
if want themer; then on2; "$HOME/.local/bin/themer-ultimate" open >/dev/null 2>&1; snap themer 3; "$HOME/.local/bin/themer-ultimate" close >/dev/null 2>&1; fi
if want obs-picker; then
  on2
  printf '["Monitor: DP-1 3440x1440", "Window: Ghostty (12)", "Window: Kopuz (309)"]' > /tmp/tu-obs-items.json
  OBS_PICKER_ITEMS=/tmp/tu-obs-items.json OBS_PICKER_RESULT=/tmp/tu-obs-result quickshell -p "$q/obs-picker" >/dev/null 2>&1 & opid=$!
  snap obs-picker 2.5; kill $opid 2>/dev/null
fi
if want screenshot; then
  on2
  img="$HOME/.local/share/wallpapers/deep-space.png"; [ -f "$img" ] || img="$here/wallpapers/h4x0r.png"
  quickshell ipc -c screenshot call editor openFile "$img" >/dev/null 2>&1
  snap screenshot 2.5
  niri msg -j windows | python3 -c 'import json,sys,subprocess
for w in json.load(sys.stdin):
    if w["title"] == "Galaxy Screenshot": subprocess.run(["niri","msg","action","close-window","--id",str(w["id"])])'
fi
niri msg action focus-workspace "$prev_ws"
