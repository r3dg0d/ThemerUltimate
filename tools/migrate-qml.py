#!/usr/bin/env python3
"""Codemod: rewrite a Quickshell widget folder from hardcoded Purple Nebula hex/fonts/radii to Theme tokens.

  migrate-qml.py DIR [DIR...] [--dry-run]

  "#b46bff"            -> Theme.primary              (reverse map of themes/purple-nebula.json)
  "#d9130e28"          -> Theme.a(Theme.card, 0.851) (#AARRGGBB keeps its alpha)
  "Cellforge"          -> Theme.ui   ("Zerodot" -> Theme.led, "NullType" -> Theme.code, "JetBrainsMono Nerd Font" -> Theme.icons)
  radius: 14           -> radius: Theme.r(14)        (scaled by the theme's radiusScale; 1.0 for Purple Nebula)
  Canvas {             -> also repaints on Theme.revision

Purple Nebula maps back to the exact original values, so a migrated widget looks identical under it.
Hex values that are not theme colours (emoji skin tones, data colours) are left alone and reported.
Lines matching KEEP (redaction fills, annotation pen colours) are never touched.
"""
import json, re, sys
from pathlib import Path
root = Path(__file__).resolve().parent.parent
neb = json.loads((root / "themes/purple-nebula.json").read_text())["colors"]
prefer = ["void", "base", "surface", "raised", "window", "sel", "line", "edge", "edgeHot", "accent", "primary", "light", "hot",
          "ink", "bright", "text2", "muted", "label", "dim", "ok", "warn", "err", "red", "pink", "cyan"]
rev = {}
for k in prefer + [k for k in neb if k not in prefer]:
    rev.setdefault(neb[k].lower(), k)
qn = lambda k: "Theme." + ("void_" if k == "void" else k)
FONTS = {"Cellforge": "Theme.ui", "Zerodot": "Theme.led", "NullType": "Theme.code", "JetBrainsMono Nerd Font": "Theme.icons"}
KEEP = [re.compile(p) for p in (r"redact", r"model: \[\"#", r"property string ink:")]
SKIP_FILES = {"Nebula.qml", "Theme.qml"}
# Exact rewrites for spots a regex can't express (the deep-space rice's visualiser + deepfake starfield).
SPECIAL = [
    ("Qt.rgba(1, 0.42, 0.84, t * 1.3)", "Theme.a(Theme.hot, t * 1.3)"),
    ("Qt.rgba(0.83, 0.72, 1, (t - 0.5) * 1.6)", "Theme.a(Theme.light, (t - 0.5) * 1.6)"),
    ("width * height / 9000 * density)", "width * height / 9000 * density * Theme.glowStars)"),
]

def migrate_text(text, report):
    out = []
    for ln in text.splitlines(keepends=True):
        if any(k.search(ln) for k in KEEP) or ln.lstrip().startswith("//"):
            out.append(ln); continue
        def hexsub(m):
            h = m.group(1).lower()
            if len(h) == 6:
                if h in [x[1:] for x in rev]: return qn(rev["#" + h])
            else:
                a, rgb = int(h[:2], 16) / 255, "#" + h[2:]
                if rgb in rev: return f"Theme.a({qn(rev[rgb])}, {round(a, 4)})"
                if rgb == "#130e28": return f"Theme.a(Theme.card, {round(a, 4)})"
            report.add("#" + h); return m.group(0)
        ln = re.sub(r'"#([0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?)"', hexsub, ln)
        # Canvas colour strings: "rgba(180,107,255,0.08)" and "rgba(242,240,255," + expr + ")"
        def rgbakey(r, g, b): return rev.get("#%02x%02x%02x" % (int(r), int(g), int(b)))
        def rgbafull(m):
            k = rgbakey(*m.group(1, 2, 3))
            if not k: return m.group(0)
            glow = " * Theme.glowNebula" if float(m.group(4)) < 0.2 else ""   # faint clouds fade with the theme's glow
            return f"Theme.rgba({qn(k)}, {m.group(4)}{glow})"
        ln = re.sub(r'"rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)"', rgbafull, ln)
        def rgbaexpr(m):
            k = rgbakey(*m.group(1, 2, 3))
            return f"Theme.rgba({qn(k)}, {m.group(4)})" if k else m.group(0)
        ln = re.sub(r'"rgba\((\d+),\s*(\d+),\s*(\d+),"\s*\+\s*(.+?)\s*\+\s*"\)"', rgbaexpr, ln)
        for a, b in SPECIAL: ln = ln.replace(a, b)
        for f, t in FONTS.items():
            ln = ln.replace(f'"{f}"', t)
        ln = re.sub(r"\b(radius\w*)(\s*:\s*)(\d+(?:\.\d+)?)(?=\s*(?:$|[;}\n]|//))", lambda m: f"{m.group(1)}{m.group(2)}Theme.r({m.group(3)})", ln)
        out.append(ln)
        # Canvas rasters only repaint when asked: repaint them whenever the theme changes
        m = re.match(r"^(\s*)Canvas\s*\{\s*$", ln)
        if m and "themeRev" not in text:
            out.append(f"{m.group(1)}    property int themeRev: Theme.revision; onThemeRevChanged: requestPaint()\n")
    return "".join(out)

def main(args):
    dry = "--dry-run" in args
    for d in [Path(a) for a in args if not a.startswith("--")]:
        for f in sorted(d.glob("*.qml")):
            if f.name in SKIP_FILES or ".bak" in f.name: continue
            src = f.read_text(); report = set()
            new = migrate_text(src, report)
            if new != src:
                n = sum(1 for a, b in zip(src.splitlines(), new.splitlines()) if a != b)
                print(f"{f}: {n} lines" + (" (dry run)" if dry else ""))
                if not dry: f.write_text(new)
            if report: print(f"  left as-is (not theme colours): {' '.join(sorted(report))}")

if __name__ == "__main__":
    main(sys.argv[1:])
