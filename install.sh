#!/usr/bin/env bash
# ThemerUltimate installer for plain NixOS (or any distro) without home-manager. Per-user, no sudo.
#
#   ./install.sh                 install / update, migrate Quickshell widgets, apply the current (or default) theme
#   ./install.sh --no-widgets    skip rewriting ~/.config/quickshell/*/ to Theme tokens
#   ./install.sh --theme ID      theme to apply at the end (default: the current one, else purple-nebula)
#   ./install.sh --dry-run       show what would change
#
# Every file it edits is first copied to <file>.bak-themer-<timestamp>. Re-running is safe.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cfg="${XDG_CONFIG_HOME:-$HOME/.config}"; data="${XDG_DATA_HOME:-$HOME/.local/share}"
share="$data/themer-ultimate"; bindir="$HOME/.local/bin"; qs="$cfg/quickshell"
ts="$(date +%Y%m%d-%H%M%S)"; WIDGETS=yes; DRY=no; THEME=""
while [ $# -gt 0 ]; do case "$1" in
  --no-widgets) WIDGETS=no ;; --dry-run) DRY=yes ;; --theme) THEME="$2"; shift ;;
  -h|--help) sed -n '2,10p' "$0"; exit 0 ;; *) echo "unknown option $1" >&2; exit 2 ;; esac; shift; done
act() { if [ "$DRY" = yes ]; then echo "  would: $*"; else "$@"; fi; }
bak() { [ -e "$1" ] && act cp -a "$1" "$1.bak-themer-$ts" && echo "  backup ${1/#$HOME/\~}.bak-themer-$ts" || true; }

echo "ThemerUltimate → $share"
# 1. payload (themes, templates, qml, shaders, wallpapers, CLI)
act mkdir -p "$share" "$bindir"
for d in bin themes templates qml shaders wallpapers app tools share icons; do
  act rm -rf "$share/$d"; act cp -r "$here/$d" "$share/$d"
done
act cp "$here/tokens.json" "$here/LICENSE" "$share/"
act ln -sfn "$share/bin/themer-ultimate" "$bindir/themer-ultimate"
TU="$share/bin/themer-ultimate"; [ "$DRY" = yes ] && TU="$here/bin/themer-ultimate"

# 2. the picker app (quickshell -c themer-ultimate)
act mkdir -p "$qs/themer-ultimate"
for f in "$here"/app/*; do act cp "$f" "$qs/themer-ultimate/"; done
act ln -sfn "$share/qml/Theme.qml" "$qs/themer-ultimate/Theme.qml"
act ln -sfn "$share/qml/Nebula.qml" "$qs/themer-ultimate/Nebula.qml"

# 3. icon + launcher entry
act mkdir -p "$data/icons/hicolor/scalable/apps" "$data/applications"
act cp "$here"/icons/*.svg "$data/icons/hicolor/scalable/apps/"
[ "$DRY" = yes ] || sed "s|@HOME@|$HOME|g" "$here/share/applications/themer-ultimate.desktop" > "$data/applications/themer-ultimate.desktop"

# 4. Quickshell widgets: hardcoded colours/fonts/radii -> Theme tokens, shared Theme.qml + Nebula.qml
if [ "$WIDGETS" = yes ] && [ -d "$qs" ]; then
  for d in "$qs"/*/; do
    d="${d%/}"; n="$(basename "$d")"
    [ "$n" = themer-ultimate ] && continue
    [ -f "$d/shell.qml" ] || continue
    first=no; [ -L "$d/Theme.qml" ] || first=yes
    # link Theme.qml before rewriting anything, so a running Quickshell hot-reloads into a working config
    act ln -sfn "$share/qml/Theme.qml" "$d/Theme.qml"
    if [ "$first" = yes ]; then   # first time: back up every QML file we may rewrite, then migrate
      for f in "$d"/*.qml; do [ -L "$f" ] || bak "$f"; done
      act python3 "$share/tools/migrate-qml.py" "$d"
    fi
    if [ -f "$d/Nebula.qml" ] && [ ! -L "$d/Nebula.qml" ]; then act rm "$d/Nebula.qml"; act ln -s "$share/qml/Nebula.qml" "$d/Nebula.qml"
    elif [ -L "$d/Nebula.qml" ]; then act ln -sfn "$share/qml/Nebula.qml" "$d/Nebula.qml"; fi
  done
fi

# 5. render everything once (writes niri/themer.kdl and ghostty/themer.conf before anything includes them)
[ -z "$THEME" ] && THEME="$(python3 "$TU" current 2>/dev/null || echo purple-nebula)"
act python3 "$TU" apply "$THEME" --no-reload

# 6. Ghostty: theme keys move to themer.conf (included last, so it wins)
g="$cfg/ghostty/config"
if [ -f "$g" ] && ! grep -q 'themer.conf' "$g"; then
  bak "$g"
  [ "$DRY" = yes ] || { grep -vE '^\s*(font-family|font-size|background-opacity|background-blur|cursor-color|cursor-text|background|foreground|selection-background|selection-foreground|palette|custom-shader|custom-shader-animation)\s*=|^# ghostfx:' "$g" > "$g.tmp"
    printf '\n# ThemerUltimate: colours, fonts, opacity and the ghostfx shader come from themer.conf\nconfig-file = ?themer.conf\n' >> "$g.tmp"; mv "$g.tmp" "$g"; }
fi

# 7. niri: include the generated colours, add the picker's window rule + Mod+Alt+T
k="$cfg/niri/config.kdl"
if [ -f "$k" ] && ! grep -q 'include "themer.kdl"' "$k"; then
  bak "$k"
  app="$cfg/niri/themer-app.kdl"   # static: the picker's window rule + keybind (separate file: niri allows one binds{} per file)
  bind='    Mod+Alt+T repeat=false hotkey-overlay-title="ThemerUltimate: theme switcher" { spawn "bash" "-c" "~/.local/bin/themer-ultimate toggle"; }'
  if grep -qE '^\s*Mod\+Alt\+T\b' "$k"; then echo "  Mod+Alt+T is already bound in niri; not adding the keybind"; bind=""; fi
  [ "$DRY" = yes ] || printf '// ThemerUltimate picker: window rule + keybind (written once by install.sh)\nwindow-rule {\n    match title="^ThemerUltimate$"\n    open-floating true\n}\nbinds {\n%s\n}\n' "$bind" > "$app"
  [ "$DRY" = yes ] || printf '\n// ---- ThemerUltimate (github.com/r3dg0d/ThemerUltimate)\ninclude "themer-app.kdl"\n// colours / focus ring / shadow / overview / lock colour for the current theme; keep this the LAST line\ninclude "themer.kdl"\n' >> "$k"
  [ "$DRY" = yes ] || niri validate -c "$k" >/dev/null 2>&1 || { echo "  niri rejected the config; restoring backup"; cp "$k.bak-themer-$ts" "$k"; }
fi

# 8. wallpaper.sh (if the rice has one): let the theme pick the wallpaper at login
w="$cfg/niri/wallpaper.sh"
if [ -f "$w" ] && ! grep -q themer-ultimate "$w"; then
  bak "$w"
  [ "$DRY" = yes ] || sed -i '2i # ThemerUltimate picks the wallpaper for the current theme (falls through to this script for Purple Nebula)\n[ -z "${THEMER_SKIP:-}" ] \&\& [ -x "$HOME/.local/bin/themer-ultimate" ] \&\& exec "$HOME/.local/bin/themer-ultimate" wallpaper' "$w"
fi

# 9. reload everything with the theme applied
act python3 "$TU" apply "$THEME"
echo "done. Mod+Alt+T (or 'themer-ultimate') opens the picker; 'themer-ultimate list' shows the themes."
