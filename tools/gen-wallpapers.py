#!/usr/bin/env python3
"""Procedurally generate the ThemerUltimate wallpapers (original artwork, MIT). numpy + pillow.
   gen-wallpapers.py OUTDIR [WIDTH HEIGHT]   -> h4x0r.png clean-light.png matte-black.png
Purple Nebula keeps the rice's own deep-space wallpaper (github.com/r3dg0d/dotfiles)."""
import sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

out = Path(sys.argv[1] if len(sys.argv) > 1 else "wallpapers"); out.mkdir(parents=True, exist_ok=True)
W = int(sys.argv[2]) if len(sys.argv) > 2 else 3840
H = int(sys.argv[3]) if len(sys.argv) > 3 else 2160
hexrgb = lambda h: np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], np.float32) / 255
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32); nx, ny = xx / W, yy / H

def fbm(rng, w, h, octaves=6, base=3):
    acc = np.zeros((h, w), np.float32); amp, tot = 1.0, 0.0
    for o in range(octaves):
        gw, gh = base * 2 ** o, max(2, int(base * 2 ** o * h / w))
        g = (rng.random((gh, gw)) * 255).astype(np.uint8)
        acc += amp * np.asarray(Image.fromarray(g).resize((w, h), Image.BICUBIC), np.float32) / 255; tot += amp; amp *= 0.55
    return acc / tot

def save(img, name):
    arr = np.clip(img * 255 + 0.5, 0, 255).astype(np.uint8)
    Image.fromarray(arr, "RGB").save(out / name, optimize=True); print("wrote", out / name)

def vignette(strength):
    d = np.sqrt(((nx - 0.5) * 1.3) ** 2 + (ny - 0.5) ** 2)
    return np.clip(1 - strength * d ** 2 * 2.2, 0, 1)[..., None]

# ---------------------------------------------------------------- H4X0R: digital rain on black
def h4x0r():
    rng = np.random.default_rng(0x4AC0)
    img = np.zeros((H, W, 3), np.float32)
    cell = 22; gw, gh = 5, 7; px = 3           # 5x7 dot-matrix glyphs, 3px dots, 22px cells
    cols, rows = W // cell, H // cell + 1
    glyphs = rng.random((64, gh, gw)) > 0.52   # a fixed alphabet of random 5x7 glyphs
    green = hexrgb("#00ff66"); head = hexrgb("#d8ffe4"); deep = hexrgb("#00b84a")
    layer = np.zeros((H, W), np.float32); heads = np.zeros((H, W), np.float32)
    for c in range(cols):
        for _ in range(rng.integers(1, 4)):
            if rng.random() > 0.8: continue
            length = int(rng.integers(8, 42)); start = int(rng.integers(-length, rows))
            for j in range(length):
                r = start + length - 1 - j          # head at the bottom of the trail
                if r < 0 or r >= rows: continue
                a = (1 - j / length) ** 1.6 * (0.35 + 0.65 * rng.random() ** 0.5)
                g = glyphs[rng.integers(0, 64)]
                y0, x0 = r * cell + 1, c * cell + 3
                for gy in range(gh):
                    for gx in range(gw):
                        if g[gy, gx]:
                            y, x = y0 + gy * px, x0 + gx * px
                            if y + px <= H and x + px <= W:
                                (heads if j == 0 else layer)[y:y + px - 1, x:x + px - 1] = np.maximum((heads if j == 0 else layer)[y:y + px - 1, x:x + px - 1], 1.0 if j == 0 else a)
    lay = Image.fromarray((layer * 255).astype(np.uint8)); hd = Image.fromarray((heads * 255).astype(np.uint8))
    glow = np.asarray(lay.filter(ImageFilter.GaussianBlur(6)), np.float32) / 255
    hglow = np.asarray(hd.filter(ImageFilter.GaussianBlur(10)), np.float32) / 255
    depth = 0.55 + 0.45 * fbm(rng, W // 8, H // 8, 4).repeat(8, 0).repeat(8, 1)[:H, :W]   # some columns dimmer
    img += layer[..., None] * depth[..., None] * green * 0.85 + glow[..., None] * deep * 0.8
    img += heads[..., None] * head * 0.9 + hglow[..., None] * green * 0.9
    img += hexrgb("#00ff66") * 0.03 * np.exp(-((ny - 0.5) ** 2) * 6)[..., None]
    scan = (0.92 + 0.08 * (np.sin(yy * np.pi / 2) ** 2))[..., None]   # faint scanlines
    save(img * scan * vignette(0.6), "h4x0r.png")

# ---------------------------------------------------------------- Clean Light: paper and soft colour
def clean_light():
    rng = np.random.default_rng(0xC1EA)
    paper = hexrgb("#f5f6fa"); img = np.ones((H, W, 3), np.float32) * paper
    def wash(cx, cy, rx, ry, col, a):
        d = ((nx - cx) / rx) ** 2 + ((ny - cy) / ry) ** 2
        return np.exp(-d * 2.2)[..., None] * (hexrgb(col) - paper) * a
    img += wash(0.12, 0.08, 0.55, 0.6, "#8c9cff", 0.42)
    img += wash(0.92, 0.95, 0.6, 0.7, "#f3a6cf", 0.32)
    img += wash(0.72, 0.18, 0.35, 0.4, "#9be3f2", 0.22)
    # thin concentric arcs, very faint
    d = np.sqrt((nx * W - W * 0.82) ** 2 + (ny * H - H * 0.2) ** 2)
    rings = np.exp(-((d % 140) - 70) ** 2 / 2.0) * np.exp(-d / (W * 0.45))
    img -= rings[..., None] * 0.035
    grain = (rng.random((H, W)).astype(np.float32) - 0.5) * 0.012
    save(img + grain[..., None], "clean-light.png")

# ---------------------------------------------------------------- Matte Black: graphite, soft light, grain
def matte_black():
    rng = np.random.default_rng(0x0B1C)
    base = hexrgb("#0b0b0b")
    light = np.exp(-(((nx - 0.3) / 0.7) ** 2 + ((ny + 0.1) / 0.9) ** 2) * 1.6)
    img = base + (hexrgb("#262626") - base) * light[..., None]
    # brushed texture: horizontal-stretched noise
    n = rng.random((H // 2, W // 64)).astype(np.float32)
    brush = np.asarray(Image.fromarray((n * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC), np.float32) / 255
    img += (brush[..., None] - 0.5) * 0.012
    # one hairline arc, barely there
    d = np.sqrt((nx * W - W * 1.05) ** 2 + (ny * H - H * 1.25) ** 2)
    img += (np.exp(-((d - H * 1.05) ** 2) / 3.0) * 0.06)[..., None]
    grain = (rng.random((H, W)).astype(np.float32) - 0.5) * 0.018
    save(img * vignette(0.35) + grain[..., None], "matte-black.png")

h4x0r(); clean_light(); matte_black()
