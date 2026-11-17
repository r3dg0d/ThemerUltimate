#!/usr/bin/env python3
"""Turn a config written in Purple Nebula colours into a ThemerUltimate template (reverse token map).
   templatize.py IN OUT [--css-rgb] : #rrggbb -> {{token}}, 'r, g, b' in rgba() -> {{token_rgb}},
   bare rrggbb (fuzzel/mako style) -> {{token_nohash}}, font names -> {{font_*}}."""
import json, re, sys
from pathlib import Path
root = Path(__file__).resolve().parent.parent
neb = json.loads((root / "themes/purple-nebula.json").read_text())["colors"]
prefer = ["void", "base", "surface", "raised", "window", "sel", "line", "edge", "edgeHot", "accent", "primary", "light", "hot",
          "ink", "bright", "text2", "muted", "label", "dim", "ok", "warn", "err", "red", "pink", "cyan"]
rev = {}
for k in prefer + [k for k in neb if k not in prefer]:
    rev.setdefault(neb[k].lower(), k)
src, dst = Path(sys.argv[1]), Path(sys.argv[2])
t = src.read_text()
unknown = set()
def hexsub(m):
    h = m.group(0).lower()
    if h[:7] in rev: return "{{" + rev[h[:7]] + "}}" + h[7:]
    unknown.add(h); return m.group(0)
t = re.sub(r"#[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?\b", hexsub, t)
def rgbsub(m):
    h = "#%02x%02x%02x" % tuple(int(x) for x in m.group(1, 2, 3))
    if h in rev: return "rgba({{" + rev[h] + "_rgb}}, "
    unknown.add(h); return m.group(0)
t = re.sub(r"rgba\((\d+),\s*(\d+),\s*(\d+),\s*", rgbsub, t)
if "--bare" in sys.argv:  # fuzzel: key=rrggbbaa
    def baresub(m):
        h = "#" + m.group(2).lower()
        if h in rev: return m.group(1) + "{{" + rev[h] + "_nohash}}" + m.group(3)
        unknown.add(h); return m.group(0)
    t = re.sub(r"^([a-z-]+=)([0-9a-fA-F]{6})([0-9a-fA-F]{2})$", baresub, t, flags=re.M)
for f, k in (("Cellforge", "ui"), ("Zerodot", "led"), ("NullType", "code"), ("JetBrainsMono Nerd Font", "icons")):
    t = t.replace(f, "{{font_" + k + "}}")
dst.write_text(t)
if unknown: print("unmapped:", sorted(unknown), file=sys.stderr)
