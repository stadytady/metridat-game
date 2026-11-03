#!/usr/bin/env python3
"""Generates every texture, material and sound of the project.

All assets are original: textures are painted procedurally into small
palettes with ordered dithering (PS1-style), sounds are synthesized.
Deterministic: the same script version always produces the same files.

    python3 tools/gen_assets.py          # from the project root
Needs numpy and Pillow.
"""
from __future__ import annotations

import math
import wave
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TEX = ROOT / "assets" / "textures"
MAT = ROOT / "assets" / "materials"
AUD = ROOT / "assets" / "audio"

BAYER4 = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) + 0.5) / 16.0


def hexc(h: str) -> np.ndarray:
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64)


def bayer(h: int, w: int) -> np.ndarray:
    return np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w]


def ramp(v: np.ndarray, colors: list[str], dither: float = 0.8) -> np.ndarray:
    """Maps a scalar field in [0,1] onto a color ramp with ordered dithering."""
    pal = np.stack([hexc(c) for c in colors])
    n = len(colors)
    h, w = v.shape
    x = np.clip(v, 0, 1) * (n - 1) + (bayer(h, w) - 0.5) * dither
    idx = np.clip(np.floor(x + 0.5), 0, n - 1).astype(int)
    return pal[idx]


def vnoise(size: int, cells: int, rng: np.random.Generator, h: int | None = None) -> np.ndarray:
    """Tileable bilinear value noise in [0,1]."""
    h = h or size
    ch = max(1, cells * h // size)
    g = rng.random((ch, cells))
    ys = np.arange(h) * ch / h
    xs = np.arange(size) * cells / size
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    fy = (ys - y0)[:, None]
    fx = (xs - x0)[None, :]
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    y1 = (y0 + 1) % ch
    x1 = (x0 + 1) % cells
    a = g[y0][:, x0]
    b = g[y0][:, x1]
    c = g[y1][:, x0]
    d = g[y1][:, x1]
    return a * (1 - fx) * (1 - fy) + b * fx * (1 - fy) + c * (1 - fx) * fy + d * fx * fy


def fbm(size: int, rng: np.random.Generator, octaves=(4, 8, 16), h: int | None = None) -> np.ndarray:
    out = np.zeros((h or size, size))
    amp, tot = 1.0, 0.0
    for c in octaves:
        out += amp * vnoise(size, c, rng, h)
        tot += amp
        amp *= 0.5
    return out / tot


def write_import(path: Path, text: str) -> None:
    # Godot adds uid/dest to .import files; keep existing ones so ids stay stable.
    if not path.exists():
        path.write_text(text)


def save(name: str, rgb: np.ndarray, alpha: np.ndarray | None = None) -> None:
    img = np.clip(rgb, 0, 255).astype(np.uint8)
    if alpha is not None:
        img = np.dstack([img, (alpha * 255).astype(np.uint8)])
        Image.fromarray(img, "RGBA").save(TEX / f"{name}.png")
    else:
        Image.fromarray(img, "RGB").save(TEX / f"{name}.png")
    # Lossless, no mipmaps: keeps the pixels crisp and stops Godot from
    # switching to VRAM compression when it detects 3D usage.
    write_import(TEX / f"{name}.png.import",
        "[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n\n"
        f"[deps]\n\nsource_file=\"res://assets/textures/{name}.png\"\n\n"
        "[params]\n\ncompress/mode=0\nmipmaps/generate=false\ndetect_3d/compress_to=0\n"
        "process/fix_alpha_border=true\n"
    )


LIME = ["#5e5039", "#7d6a4c", "#9a8461", "#b39d76", "#c8b48a", "#dacaa0"]
PLASTER = ["#6f5f48", "#8f7b5e", "#ab9675", "#c2ae89", "#d4c29c", "#e0d2ae"]
TERRA = ["#3e1a0e", "#5e2814", "#7c361c", "#a4522e", "#c06a3c", "#d98b55"]
WOOD = ["#2b1d12", "#3f2a19", "#57391f", "#6e4a2a", "#8a6038", "#a07446"]
PAVE = ["#4a4236", "#665b4a", "#81745e", "#9b8c72", "#b3a387", "#c7b89a"]
EARTH = ["#4e3d29", "#6a5236", "#836844", "#9c7f55", "#b39769"]
OLIVE = ["#1c220d", "#2a3214", "#3a4219", "#4b5320", "#5f6a2a", "#7d8036", "#9a9346"]
ROCK = ["#3b362e", "#554d40", "#6f6553", "#8a7e68", "#a3967c", "#bcae90"]
CLAY = ["#6e3b1f", "#8f5130", "#ad6a40", "#c4825a", "#d49b70", "#e2b48a"]
BRONZE = ["#3a2814", "#5c3f1e", "#7f5a2a", "#a87b3a", "#c9953f"]
GOLD = ["#4a3510", "#7a5a1a", "#a87b2a", "#c9953f", "#e0b860", "#f2d68a"]
SEA = ["#1f3442", "#2a4556", "#2f4a5e", "#3b5a6e", "#4f7480", "#5d8a85", "#86a9a6"]


def limestone(rng):
    s = 64
    field = np.zeros((s, s))
    mortar = np.zeros((s, s), bool)
    for row in range(4):
        y0 = row * 16
        tone_off = rng.integers(0, s)
        cuts = []
        x = 0
        while x < s - 10:
            cuts.append(x)
            x += int(rng.integers(14, 27))
        for i, cx in enumerate(cuts):
            nx = cuts[i + 1] if i + 1 < len(cuts) else s
            xs = (np.arange(cx, nx) + tone_off) % s
            field[y0:y0 + 16, xs] = rng.uniform(0.35, 0.7)
            mortar[y0:y0 + 16, (cx + tone_off) % s] = True
        mortar[y0 + 15, :] = True
        field[y0, :] += 0.12
        field[y0 + 14, :] -= 0.1
    field += (fbm(s, rng, (8, 16, 32)) - 0.5) * 0.35
    field[mortar] = 0.08
    save("limestone", ramp(field, LIME))


def column(rng):
    s = 64
    x = np.arange(s)
    flute = 0.45 + 0.28 * np.cos((x % 8) / 8 * 2 * np.pi)
    field = np.tile(flute, (s, 1)) + (fbm(s, rng, (8, 16)) - 0.5) * 0.3
    save("column", ramp(field, LIME))


def plaster(rng):
    s = 64
    field = 0.62 + (fbm(s, rng, (4, 8)) - 0.5) * 0.3 + (vnoise(s, 32, rng) - 0.5) * 0.12
    stains = vnoise(s, 4, rng)
    field -= np.where(stains > 0.68, (stains - 0.68) * 1.2, 0)
    save("plaster", ramp(field, PLASTER))


def roof(rng):
    s = 64
    y, x = np.mgrid[0:s, 0:s]
    row = y // 8
    off = (row % 2) * 4
    u = ((x + off) % 8) / 8
    v = (y % 8) / 8
    tone = rng.uniform(-0.08, 0.08, (8, 8))[row, ((x + off) // 8) % 8]
    field = 0.25 + 0.45 * np.sin(np.pi * u) + 0.25 * v + tone + (vnoise(s, 16, rng) - 0.5) * 0.15
    field[(y % 8) == 0] -= 0.25
    save("roof", ramp(field, TERRA))


def wood_field(rng, s=64):
    y, x = np.mgrid[0:s, 0:s]
    edges = [0]
    while edges[-1] < s - 8:
        edges.append(edges[-1] + int(rng.integers(9, 13)))
    plank = np.zeros(s, int)
    for i, e in enumerate(edges):
        plank[e:] = i
    tones = rng.uniform(-0.1, 0.1, len(edges) + 1)
    n = vnoise(s, 8, rng)
    field = 0.5 + tones[plank][None, :] + 0.13 * np.sin(y * 0.45 + n * 6 + plank[None, :] * 2.1)
    gaps = np.isin(x, edges)
    field[gaps] = 0.05
    return field


def wood(rng):
    save("wood", ramp(wood_field(rng), WOOD))


def door(rng):
    s = 64
    field = wood_field(rng)
    field[10:15, :] += 0.18
    field[49:54, :] += 0.18
    rgb = ramp(field, WOOD)
    for yy in (12, 51):
        for xx in range(6, 64, 13):
            rgb[yy - 1:yy + 1, xx:xx + 2] = hexc("#c9953f")
            rgb[yy + 1, xx:xx + 2] = hexc("#5c3f1e")
    save("door", rgb)


def voronoi(s, n, rng):
    pts = rng.random((n, 2)) * s
    y, x = np.mgrid[0:s, 0:s]
    d = np.full((n, s, s), 1e9)
    for i, (px, py) in enumerate(pts):
        dx = np.abs(x - px)
        dy = np.abs(y - py)
        dx = np.minimum(dx, s - dx)
        dy = np.minimum(dy, s - dy)
        d[i] = np.sqrt(dx * dx + dy * dy)
    order = np.sort(d, axis=0)
    return np.argmin(d, axis=0), order[1] - order[0]


def paving(rng):
    s = 64
    cell, edge = voronoi(s, 14, rng)
    tones = rng.uniform(0.35, 0.75, 14)
    field = tones[cell] + (fbm(s, rng, (8, 16)) - 0.5) * 0.3
    field[edge < 1.4] = 0.06
    save("paving", ramp(field, PAVE))


def earth(rng):
    s = 64
    field = 0.5 + (fbm(s, rng, (4, 8, 16)) - 0.5) * 0.7
    rgb = ramp(field, EARTH)
    for _ in range(40):
        px, py = rng.integers(0, s, 2)
        rgb[py, px] = hexc(EARTH[-1])
    tuft = vnoise(s, 6, rng) > 0.66
    grass = ramp(0.4 + vnoise(s, 32, rng) * 0.5, OLIVE[2:6])
    mask = tuft & (rng.random((s, s)) > 0.35)
    rgb[mask] = grass[mask]
    save("earth", rgb)


def grass(rng):
    s = 64
    field = 0.35 + (fbm(s, rng, (4, 8)) - 0.5) * 0.5
    for _ in range(90):
        x, y = rng.integers(0, s, 2)
        ln = int(rng.integers(2, 6))
        for k in range(ln):
            field[(y - k) % s, x] += 0.25
    save("grass", ramp(field, OLIVE))


def rock(rng):
    s = 64
    n = fbm(s, rng, (4, 8, 16))
    ridged = 1 - np.abs(n - 0.5) * 2
    field = 0.25 + 0.6 * n
    field[ridged > 0.93] -= 0.3
    save("rock", ramp(field, ROCK))


def foliage(rng):
    s = 64
    field = np.full((s, s), 0.18)
    for _ in range(160):
        cx, cy = rng.uniform(0, s, 2)
        r = rng.uniform(1.5, 3.2)
        y, x = np.mgrid[0:s, 0:s]
        dx = (x - cx + s / 2) % s - s / 2
        dy = (y - cy + s / 2) % s - s / 2
        m = dx * dx + dy * dy < r * r
        shade = 0.45 + 0.25 * (-(dx + dy) / (2 * r)) + rng.uniform(-0.1, 0.15)
        field[m] = shade[m]
    save("foliage", ramp(field, OLIVE[:6]))


def bark(rng):
    s = 32
    field = 0.45 + (vnoise(s, 4, rng, s) - 0.5) * 0.3
    field += 0.25 * (vnoise(s, 16, rng) - 0.5)
    field = np.repeat(field[:, ::4], 4, axis=1) * 0.6 + field * 0.4
    save("bark", ramp(field, ["#2a231c", "#3d3328", "#524536", "#6a5a46", "#7d6b52"]))


def clay(rng):
    s = 64
    y = np.arange(s)[:, None]
    field = 0.6 + 0.06 * np.sin(y * 1.3) + (fbm(s, rng, (4, 8)) - 0.5) * 0.3
    field = np.broadcast_to(field, (s, s)).copy()
    field[6:10, :] = 0.12
    field[54:56, :] = 0.15
    save("clay", ramp(field, CLAY))


def redfigure(rng):
    s = 64
    black = hexc("#1b1512")
    black2 = hexc("#2c221c")
    orange = hexc("#c0703a")
    orange2 = hexc("#d98b55")
    rgb = np.empty((s, s, 3))
    rgb[:] = black
    rgb[rng.random((s, s)) > 0.85] = black2
    # meander (Greek key) band
    rgb[4:12, :] = orange
    key = ["11111111", "10000001", "10111101", "10100101", "10100001", "10111111"]
    for x0 in range(0, s, 8):
        for ky, line in enumerate(key):
            for kx, ch in enumerate(line):
                if ch == "1" and ky < 6:
                    rgb[5 + ky, x0 + kx] = black
    # two figures in reserved clay
    figs = [
        "..11..", "..11..", ".1111.", "111111", "1.11.1", "..11..", ".1111.", ".1..1.", ".1..1.", "11..11",
    ]
    for fx in (10, 40):
        for fy, line in enumerate(figs):
            for kx, ch in enumerate(line):
                if ch == "1":
                    rgb[22 + fy * 2:24 + fy * 2, fx + kx * 2:fx + kx * 2 + 2] = orange if fy % 3 else orange2
    rgb[50:58, :] = orange
    for x0 in range(0, s, 6):
        rgb[50:56, x0 + 2:x0 + 4] = black
    save("redfigure", rgb)


def bronze(rng):
    s = 32
    field = 0.6 + (fbm(s, rng, (4, 8)) - 0.5) * 0.6
    rgb = ramp(field, BRONZE)
    patina = vnoise(s, 6, rng) > 0.78
    rgb[patina] = ramp(vnoise(s, 16, rng), ["#4d7470", "#5d8a85", "#7aa39b"])[patina]
    save("bronze", rgb)


def gold(rng):
    s = 32
    y, x = np.mgrid[0:s, 0:s]
    r = np.hypot(x - 15.5, y - 15.5) / 16
    field = 0.75 - r * 0.4 + (vnoise(s, 8, rng) - 0.5) * 0.2
    # raised griffin-like relief: a rough blob with a beak stroke
    blob = ((x - 14) ** 2 / 30 + (y - 17) ** 2 / 18) < 1
    field[blob] += 0.2
    field[(y == 10) & (x > 16) & (x < 24)] += 0.25
    field[r > 0.9] = 0.45
    save("coin", ramp(field, GOLD))


def water(rng):
    s = 64
    field = 0.45 + (fbm(s, rng, (2, 4, 8)) - 0.5) * 0.5
    for _ in range(26):
        x, y = rng.integers(0, s, 2)
        ln = int(rng.integers(3, 9))
        for k in range(ln):
            field[y, (x + k) % s] += 0.3
    save("water", ramp(field, SEA))


def cloth(rng):
    s = 64
    x = np.arange(s)
    stripe = np.where((x // 8) % 2 == 0, 0.0, 1.0)
    fold = 0.12 * np.sin(x / 64 * 2 * np.pi * 4)
    base = fbm(s, rng, (4, 8)) * 0.25
    a = ramp(0.45 + fold[None, :] + base, ["#7a5a2a", "#a07a3a", "#c9953f", "#d9ae5c"])
    b = ramp(0.45 + fold[None, :] + base, ["#5e2814", "#7c361c", "#a4522e", "#c06a3c"])
    rgb = np.where(stripe[None, :, None] > 0, b, a)
    save("cloth", rgb)


def basket(rng):
    s = 32
    y, x = np.mgrid[0:s, 0:s]
    over = ((x // 4) + (y // 4)) % 2 == 0
    field = np.where(over, 0.65 - (y % 4) * 0.08, 0.4 - (x % 4) * 0.06)
    field += (vnoise(s, 8, rng) - 0.5) * 0.15
    save("basket", ramp(field, ["#4a3518", "#6b4f26", "#8d6c38", "#ad8a4c", "#c4a464"]))


def figurine(rng):
    s = 32
    field = 0.55 + (fbm(s, rng, (4, 8)) - 0.5) * 0.5
    rgb = ramp(field, CLAY)
    traces = vnoise(s, 12, rng) > 0.86
    rgb[traces] = hexc("#e2d3b5")
    save("figurine", rgb)


GREEK = {
    "Α": ["010", "101", "111", "101", "101"],
    "Β": ["110", "101", "110", "101", "110"],
    "Δ": ["010", "010", "101", "101", "111"],
    "Ε": ["111", "100", "110", "100", "111"],
    "Η": ["101", "101", "111", "101", "101"],
    "Ι": ["010", "010", "010", "010", "010"],
    "Κ": ["101", "110", "100", "110", "101"],
    "Λ": ["010", "010", "101", "101", "101"],
    "Ν": ["101", "111", "111", "101", "101"],
    "Ο": ["111", "101", "101", "101", "111"],
    "Π": ["111", "101", "101", "101", "101"],
    "Ρ": ["110", "101", "110", "100", "100"],
    "Σ": ["111", "100", "010", "100", "111"],
    "Τ": ["111", "010", "010", "010", "010"],
    "Υ": ["101", "101", "010", "010", "010"],
    "Χ": ["101", "101", "010", "101", "101"],
    "Ω": ["010", "101", "101", "010", "111"],
    " ": ["000"] * 5,
}


def inscription(rng):
    w, h = 128, 64
    field = 0.62 + (fbm(w, rng, (8, 16), h) - 0.5) * 0.3
    rgb = ramp(field, LIME)
    lines = ["ΠΑΙΡΙΣΑΔΗΣ", "ΛΕΥΚΩΝΟΣ", "ΑΡΧΩΝ ΒΟΣΠΟΡΟΥ", "ΑΠΟΛΛΩΝΙ"]
    dark, lit = hexc(LIME[0]), hexc(LIME[-1])
    for li, text in enumerate(lines):
        width = len(text) * 8
        x0 = (w - width) // 2
        y0 = 6 + li * 14
        for ci, ch in enumerate(text):
            g = GREEK[ch]
            for gy, row in enumerate(g):
                for gx, bit in enumerate(row):
                    if bit == "1":
                        px, py = x0 + ci * 8 + gx * 2, y0 + gy * 2
                        rgb[py:py + 2, px:px + 2] = dark
                        if py + 2 < h:
                            rgb[py + 2, px:px + 2] = np.maximum(rgb[py + 2, px:px + 2], lit * 0.9)
    save("inscription", rgb)


def sky(rng):
    # Panorama is magnified a lot on screen: smooth bands, no dither, like PS1 skies.
    w, h = 512, 256
    v = np.linspace(0, 1, h)[:, None] * np.ones((1, w))
    t = np.clip(v / 0.5, 0, 1)  # 0 = zenith, 1 = horizon
    field = t ** 2.4
    bands = ["#2b4356", "#344f63", "#3f5b6c", "#527077", "#738276", "#9a8a70", "#c08a62",
             "#d8925a", "#e6a466", "#efb678", "#f2c48c"]
    rgb = ramp(field, bands, 0.0)
    clouds = vnoise(w, 12, rng, h)
    for cy, thick, col in ((0.40, 0.012, "#c98a6a"), (0.445, 0.008, "#dba07a"), (0.33, 0.01, "#9a7a6a")):
        streak = (np.abs(v - cy - (clouds - 0.5) * 0.02) < thick) & (clouds > 0.48)
        rgb[streak] = hexc(col)
    rgb[v >= 0.5] = hexc("#d9a774")
    save("sky", rgb)


def sky_panorama(rng, name, bands, field_pow, clouds, stars=0, moon=None):
    """Banded panorama like sky(): no dither, the image is magnified a lot."""
    w, h = 512, 256
    v = np.linspace(0, 1, h)[:, None] * np.ones((1, w))
    t = np.clip(v / 0.5, 0, 1)
    rgb = ramp(t ** field_pow, bands, 0.0)
    noise = vnoise(w, 12, rng, h)
    for cy, thick, col in clouds:
        streak = (np.abs(v - cy - (noise - 0.5) * 0.02) < thick) & (noise > 0.48)
        rgb[streak] = hexc(col)
    for _ in range(stars):
        x = int(rng.integers(0, w))
        y = int(rng.integers(0, int(h * 0.42)))
        rgb[y, x] = hexc("#f2ecd8") if rng.random() < 0.7 else hexc("#c8d4f0")
    if moon:
        mx, my, r = moon
        yy, xx = np.mgrid[0:h, 0:w]
        d = np.hypot(xx - mx, (yy - my) * 1.0)
        rgb[d < r + 3] = rgb[d < r + 3] * 0.6 + hexc("#56607a") * 0.4
        rgb[d < r] = hexc("#e8e4d0")
        rgb[(d < r) & (xx > mx + r * 0.35)] = hexc("#c8c4b0")
    rgb[v >= 0.5] = hexc(bands[-1])
    save(name, rgb)


def sky_dusk(rng):
    sky_panorama(rng, "sky_dusk",
                 ["#232a44", "#2e3350", "#3d3a5a", "#57435e", "#7a4c5c", "#a2554e", "#c8603e", "#e07a42", "#ec9452"],
                 2.2, ((0.40, 0.012, "#5e3a48"), (0.445, 0.008, "#7e4248"), (0.33, 0.01, "#3e3450")), stars=25)


def sky_night(rng):
    sky_panorama(rng, "sky_night",
                 ["#070b18", "#0b1122", "#10182e", "#162038", "#1d2842", "#26324c"],
                 1.6, ((0.42, 0.01, "#1a2236"), (0.36, 0.008, "#151c30")), stars=420, moon=(140, 70, 9))


def skin(rng):
    s = 32
    field = 0.55 + (vnoise(s, 4, rng) - 0.5) * 0.25
    save("skin", ramp(field, ["#6e4630", "#8a5a3c", "#a2704c", "#b8865e"]))


def chiton(rng):
    s = 64
    x = np.arange(s)
    folds = 0.5 + 0.18 * np.sin(x / s * 2 * np.pi * 6 + vnoise(s, 4, rng)[0] * 3)
    field = np.tile(folds, (s, 1)) + (fbm(s, rng, (4, 8)) - 0.5) * 0.25
    rgb = ramp(field, ["#7a6a52", "#9a8a6c", "#b8a888", "#d0c2a2", "#e0d4b6"])
    rgb[56:60, :] = hexc("#7c361c")  # woven border
    save("chiton", rgb)


def hair(rng):
    s = 16
    field = 0.5 + (vnoise(s, 4, rng) - 0.5) * 0.5
    save("hair", ramp(field, ["#140e0a", "#22180f", "#33241a"]))


def mud(rng):
    s = 64
    field = 0.5 + (fbm(s, rng, (4, 8, 16)) - 0.5) * 0.6
    field[(np.arange(s)[:, None] % 11 == 0) & (np.ones((1, s)) > 0)] -= 0.2
    save("mud", ramp(field, ["#4a3426", "#634634", "#7c5a42", "#946e52", "#aa8464"]))


def net(rng):
    # Knotted diamond mesh, cut out by alpha (psx_cutout).
    s = 64
    y, x = np.mgrid[0:s, 0:s]
    cord = ((x + y) % 16 < 2) | ((x - y) % 16 < 2)
    knots = ((x + y) % 16 < 3) & ((x - y) % 16 < 3)
    field = 0.45 + vnoise(s, 8, rng) * 0.3 + knots * 0.15
    rgb = ramp(field, ["#3a3226", "#55493a", "#6e624e", "#857a63"], dither=0.0)
    alpha = (cord | knots).astype(np.float32)
    alpha[rng.random((s, s)) < 0.015] = 0.0  # a few torn strands
    save("net", rgb, alpha)


def fish(rng):
    # Silver flank, dark back, scale rows; v runs back (0) to belly (1).
    s = 32
    y, x = np.mgrid[0:s, 0:s]
    field = 0.25 + 0.6 * (y / s) + 0.08 * np.sin(x * 1.6 + (y % 4) * 1.2) + (vnoise(s, 4, rng) - 0.5) * 0.15
    save("fish", ramp(field, ["#1e2a30", "#34474e", "#5e7378", "#8fa3a2", "#b9c6c0", "#d8ddd2"]))


def sand(rng):
    # Pale beach sand with scattered pebbles and shell grit.
    s = 64
    field = 0.5 + (fbm(s, rng, (8, 16, 32)) - 0.5) * 0.45
    pebbles = rng.random((s, s))
    field[pebbles < 0.02] -= 0.35
    field[pebbles > 0.992] += 0.3
    save("sand", ramp(field, ["#7a6a4e", "#94826a", "#ab9878", "#c0ac88", "#d2bf98", "#e2d2ac"]))


def feather(rng):
    # Rows of rounded feather tips, light; tinted per breed in MATERIALS.
    s = 32
    y, x = np.mgrid[0:s, 0:s]
    row = y // 4
    tip = ((x + row * 2) % 6 - 2.5) ** 2 / 6.0 + (y % 4) / 4.0
    field = 0.75 - 0.35 * (tip > 1.0) + (vnoise(s, 4, rng) - 0.5) * 0.2
    save("feather", ramp(field, ["#8a7e6c", "#b4aa96", "#d6ccb6", "#ece4d0"]))


def fleece(rng):
    # Curly sheepskin: cream locks with grey-brown shadows.
    s = 32
    field = 0.55 + (vnoise(s, 8, rng) - 0.5) * 0.5 + (rng.random((s, s)) - 0.5) * 0.18
    save("fleece", ramp(field, ["#6e6250", "#9a8c74", "#c2b496", "#dccfb2", "#ece2c8"]))


def worn(rng):
    # Stone polished smooth by centuries of feet: pale, even, with a ragged
    # dithered edge (cut out by alpha) so it melts into the paving around it.
    s = 64
    y, x = np.mgrid[0:s, 0:s]
    r = np.hypot((x - s / 2) / (s / 2), (y - s / 2) / (s / 2))
    edge = r + (vnoise(s, 6, rng) - 0.5) * 0.5
    field = 0.6 + (vnoise(s, 4, rng) - 0.5) * 0.15
    rgb = ramp(field, ["#a89b80", "#bfb193", "#d2c4a4", "#ded2b4"], dither=0.3)
    alpha = (edge < 0.8).astype(np.float32)
    alpha[(edge >= 0.65) & (edge < 0.8) & (bayer(s, s) > 0.5)] = 0.0  # dithered rim
    save("worn", rgb, alpha)


def fur(rng):
    # Short tan dog's coat with darker streaks.
    s = 32
    y, x = np.mgrid[0:s, 0:s]
    streak = 0.08 * np.sin(x * 0.9 + vnoise(s, 4, rng) * 4)
    field = 0.55 + streak + (rng.random((s, s)) - 0.5) * 0.2
    save("fur", ramp(field, ["#4a3220", "#6e4a2c", "#8c6238", "#a87a48", "#c09060"]))


def dark(rng):
    s = 16
    save("dark", ramp(0.4 + vnoise(s, 4, rng) * 0.3, ["#140f0b", "#1f1813", "#2a211a"]))


def white(rng):
    save("white", np.full((8, 8, 3), 255.0))


TEXTURES = [limestone, column, plaster, roof, wood, door, paving, earth, grass, rock, foliage, bark,
            clay, redfigure, bronze, gold, water, cloth, basket, figurine, inscription, sky, dark, white]

# Screen-filling surfaces swim too much with full affine mapping.
AFFINE = {"sand": 0.25, "sand_wet": 0.25, "earth": 0.25, "grass": 0.25, "rock": 0.4, "paving": 0.5, "distant_land": 0.0}

# name: (shader, texture, tint, uv_scale)
MATERIALS = {
    "limestone": ("psx_lit", "limestone", "#ffffff", (0.5, 0.5)),
    "column": ("psx_lit", "column", "#ffffff", (1.0, 0.5)),
    "plaster": ("psx_lit", "plaster", "#ffffff", (0.4, 0.4)),
    "roof": ("psx_lit", "roof", "#ffffff", (0.5, 0.5)),
    "wood": ("psx_lit", "wood", "#ffffff", (0.6, 0.6)),
    "door": ("psx_lit", "door", "#ffffff", (1.0, 1.0)),
    "paving": ("psx_lit", "paving", "#ffffff", (0.35, 0.35)),
    "earth": ("psx_lit", "earth", "#ffffff", (0.12, 0.12)),
    "grass": ("psx_lit", "grass", "#ffffff", (0.15, 0.15)),
    "rock": ("psx_lit", "rock", "#ffffff", (0.3, 0.3)),
    "foliage": ("psx_lit", "foliage", "#ffffff", (0.8, 0.8)),
    "cypress": ("psx_lit", "foliage", "#9aa08a", (0.8, 0.8)),
    "bark": ("psx_lit", "bark", "#ffffff", (1.0, 0.5)),
    "clay": ("psx_lit", "clay", "#ffffff", (1.0, 1.0)),
    "redfigure": ("psx_lit", "redfigure", "#ffffff", (1.0, 1.0)),
    "bronze": ("psx_lit", "bronze", "#ffffff", (1.0, 1.0)),
    "gold": ("psx_lit", "coin", "#ffffff", (1.0, 1.0)),
    "cloth": ("psx_lit", "cloth", "#ffffff", (0.5, 0.5)),
    "sail": ("psx_lit", "cloth", "#c8b8a0", (0.3, 0.3)),
    "hull": ("psx_lit", "wood", "#6a5a4a", (0.4, 0.4)),
    "basket": ("psx_lit", "basket", "#ffffff", (1.0, 1.0)),
    "figurine": ("psx_lit", "figurine", "#ffffff", (1.0, 1.0)),
    "inscription": ("psx_lit", "inscription", "#ffffff", (1.0, 1.0)),
    "dark": ("psx_lit", "dark", "#ffffff", (1.0, 1.0)),
    "distant_land": ("psx_lit", "earth", "#8a8070", (0.01, 0.01)),
    "marker": ("psx_unlit", "white", "#e8b34a", (1.0, 1.0)),
    "fire": ("psx_unlit", "white", "#ffb347", (1.0, 1.0)),
    "flame": ("psx_unlit", "white", "#ffd27a", (1.0, 1.0)),
    "skin": ("psx_lit", "skin", "#ffffff", (2.0, 2.0)),
    "chiton": ("psx_lit", "chiton", "#ffffff", (1.0, 1.0)),
    "chiton_dark": ("psx_lit", "chiton", "#a08a78", (1.0, 1.0)),
    "hair": ("psx_lit", "hair", "#ffffff", (2.0, 2.0)),
    "mud": ("psx_lit", "mud", "#ffffff", (0.5, 0.5)),
    "sand": ("psx_lit", "sand", "#ffffff", (0.25, 0.25)),
    "sand_wet": ("psx_lit", "sand", "#8f8476", (0.25, 0.25)),
    "hen": ("psx_lit", "feather", "#c0864e", (1.0, 1.0)),
    "hen_white": ("psx_lit", "feather", "#ffffff", (1.0, 1.0)),
    "rooster": ("psx_lit", "feather", "#8a4a26", (1.0, 1.0)),
    "rooster_tail": ("psx_lit", "feather", "#2c3a2e", (1.0, 1.0)),
    "comb": ("psx_lit", "white", "#b42a1e", (1.0, 1.0)),
    "beak": ("psx_lit", "white", "#d8a440", (1.0, 1.0)),
    "fleece": ("psx_lit", "fleece", "#ffffff", (2.0, 2.0)),
    "worn": ("psx_cutout", "worn", "#ffffff", (1.0, 1.0)),
    "fur": ("psx_lit", "fur", "#ffffff", (2.0, 2.0)),
    "pigeon": ("psx_lit", "feather", "#8c93a2", (1.0, 1.0)),
    "net": ("psx_cutout", "net", "#ffffff", (1.5, 1.5)),
    "fish": ("psx_lit", "fish", "#ffffff", (1.0, 1.0)),
    "water": ("psx_water", "water", "#ffffff", (1.0, 1.0)),
}


def materials():
    for name, (shader, tex, tint, uv) in MATERIALS.items():
        c = hexc(tint) / 255
        (MAT / f"{name}.tres").write_text(
            "[gd_resource type=\"ShaderMaterial\" load_steps=3 format=3]\n\n"
            f"[ext_resource type=\"Shader\" path=\"res://assets/shaders/{shader}.gdshader\" id=\"1_s\"]\n"
            f"[ext_resource type=\"Texture2D\" path=\"res://assets/textures/{tex}.png\" id=\"2_t\"]\n\n"
            "[resource]\n"
            f"resource_name = \"{name}\"\n"
            "shader = ExtResource(\"1_s\")\n"
            "shader_parameter/albedo_tex = ExtResource(\"2_t\")\n"
            f"shader_parameter/tint = Color({c[0]:.4f}, {c[1]:.4f}, {c[2]:.4f}, 1)\n"
            f"shader_parameter/uv_scale = Vector2({uv[0]}, {uv[1]})\n"
            + (f"shader_parameter/affine_amount = {AFFINE[name]}\n" if name in AFFINE else "")
        )


# ---------------------------------------------------------------- audio

SR = 22050


LOOPS = {"wind", "waves", "fire", "dream_drone"}


def write_wav(name: str, x: np.ndarray) -> None:
    x = np.clip(x, -1, 1)
    data = (x * 32000).astype("<i2").tobytes()
    with wave.open(str(AUD / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    # Ambient beds loop seamlessly (they are filtered circularly); one-shots do not.
    loop = name in LOOPS
    write_import(AUD / f"{name}.wav.import",
        "[remap]\n\nimporter=\"wav\"\ntype=\"AudioStreamWAV\"\n\n"
        f"[deps]\n\nsource_file=\"res://assets/audio/{name}.wav\"\n\n"
        "[params]\n\nforce/8_bit=false\nforce/mono=true\nforce/max_rate=false\n"
        f"edit/trim=false\nedit/normalize=false\nedit/loop_mode={2 if loop else 0}\n"
        "edit/loop_begin=0\nedit/loop_end=-1\ncompress/mode=0\n"
    )


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    # FFT brick-wall with a soft edge: fast and loop-safe for periodic signals.
    f = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    f *= 1 / (1 + (freqs / cutoff) ** 4)
    return np.fft.irfft(f, len(x))


def bandpass(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    f = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    f *= (1 / (1 + (freqs / hi) ** 4)) * (1 - 1 / (1 + (freqs / lo) ** 4))
    return np.fft.irfft(f, len(x))


def norm(x: np.ndarray, peak: float = 0.8) -> np.ndarray:
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def periodic_env(n: int, cycles: int, rng, sharp: float = 2.0) -> np.ndarray:
    t = np.arange(n) / n
    env = np.zeros(n)
    for k in range(1, 4):
        env += rng.uniform(0.3, 1.0) * np.sin(2 * np.pi * cycles * k * t + rng.uniform(0, 6.28)) / k
    env = (env - env.min()) / (env.max() - env.min())
    return env ** sharp


def wind(rng):
    n = SR * 16
    noise = rng.standard_normal(n)
    # FFT filtering is circular, so the result loops seamlessly.
    low = lowpass(noise, 500)
    whistle = bandpass(noise, 700, 1100)
    env = 0.35 + 0.65 * periodic_env(n, 2, rng, 1.5)
    env2 = periodic_env(n, 3, rng, 3.0)
    write_wav("wind", norm(low * env + 0.25 * whistle * env2, 0.6))


def waves(rng):
    n = SR * 18
    noise = rng.standard_normal(n)
    t = np.arange(n) / n
    swell = np.zeros(n)
    for k in range(3):  # 3 breakers per loop, slightly irregular
        c = (k + rng.uniform(0.1, 0.3)) / 3
        d = (t - c) % 1
        swell += np.where(d < 0.12, d / 0.12, np.exp(-(d - 0.12) * 9)) * rng.uniform(0.7, 1.0)
    crash = lowpass(noise, 2200) * swell
    rumble = lowpass(noise, 180) * (0.5 + 0.5 * swell)
    write_wav("waves", norm(crash + 0.8 * rumble, 0.7))


def gull(rng, idx):
    dur = rng.uniform(0.9, 1.4)
    n = int(SR * dur)
    out = np.zeros(n + SR // 2)
    calls = int(rng.integers(2, 4))
    pos = 0
    for _ in range(calls):
        ln = int(SR * rng.uniform(0.22, 0.35))
        t = np.arange(ln) / SR
        f0 = rng.uniform(1300, 1600)
        f = f0 + 500 * np.exp(-t * 18) - 350 * t / t[-1]
        phase = 2 * np.pi * np.cumsum(f) / SR
        tone = np.sin(phase) + 0.5 * np.sin(2 * phase + 0.4) + 0.25 * np.sin(3 * phase)
        tone *= np.minimum(1, t / 0.02) * np.exp(-t * 5)
        tone += 0.15 * rng.standard_normal(ln) * np.exp(-t * 8)
        out[pos:pos + ln] += tone
        pos += ln + int(SR * rng.uniform(0.05, 0.15))
    write_wav(f"gull_{idx}", norm(bandpass(out, 600, 5000), 0.5))


def cluck(rng, idx):
    # A hen's few low, nasal clucks.
    out = np.zeros(int(SR * 0.9))
    pos = 0
    for _ in range(int(rng.integers(2, 5))):
        ln = int(SR * rng.uniform(0.06, 0.1))
        t = np.arange(ln) / SR
        f = rng.uniform(380, 520) * (1 + 0.25 * np.exp(-t * 40))
        ph = 2 * np.pi * np.cumsum(f) / SR
        tone = np.sign(np.sin(ph)) * 0.4 + np.sin(2 * ph) * 0.5 + np.sin(3 * ph) * 0.3
        tone *= np.minimum(1, t / 0.008) * np.exp(-t * 30)
        out[pos:pos + ln] += tone
        pos += ln + int(SR * rng.uniform(0.07, 0.16))
    write_wav(f"cluck_{idx}", norm(bandpass(out, 300, 3500), 0.45))


def squawk(rng):
    # Alarm: a rising, rough cackle while scattering.
    ln = int(SR * 0.7)
    t = np.arange(ln) / SR
    f = 700 + 500 * np.abs(np.sin(t * 2 * np.pi * 7))
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) + 0.6 * np.sin(2 * ph) + 0.4 * rng.standard_normal(ln) * 0.5
    tone *= np.minimum(1, t / 0.02) * np.exp(-t * 3.5) * (0.6 + 0.4 * np.sign(np.sin(t * 2 * np.pi * 9)))
    write_wav("squawk", norm(bandpass(tone, 400, 4500), 0.5))


def dream_drone(rng):
    """Seamless 24 s bed for the dream: a low D and its fifth beating slowly,
    with a breath of filtered noise. Every partial has a whole number of
    cycles in the loop and the noise is filtered circularly, so it loops."""
    dur = 24.0
    n = int(SR * dur)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for f, a in ((36.75, 1.0), (55.125, 0.55), (73.5, 0.35), (110.25, 0.12)):
        f = round(f * dur) / dur  # whole cycles per loop
        beat = 1.0 + 0.25 * np.sin(2 * np.pi * (3 / dur) * t + rng.uniform(0, 6.28))
        out += a * np.sin(2 * np.pi * f * t) * beat
    breath = lowpass(rng.standard_normal(n), 300) * (0.6 + 0.4 * np.sin(2 * np.pi * (2 / dur) * t))
    out += 2.5 * breath
    write_wav("dream_drone", norm(out, 0.6))


def dog_howl(rng):
    """A dog howling far off: a long rising and falling cry with vibrato,
    softened and smeared as if heard through fog."""
    dur = 3.2
    n = int(SR * dur)
    t = np.arange(n) / SR
    contour = 470 + 230 * np.sin(np.pi * np.clip(t / 2.6, 0, 1)) ** 0.7 - 60 * np.clip((t - 2.0) / 1.0, 0, 1)
    f = contour * (1 + 0.012 * np.sin(2 * np.pi * 5.5 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) + 0.45 * np.sin(2 * ph) + 0.2 * np.sin(3 * ph)
    env = np.clip(t / 0.35, 0, 1) * np.clip((dur - t) / 0.9, 0, 1)
    tone *= env
    tone += 0.08 * lowpass(rng.standard_normal(n), 1500) * env
    write_wav("dog_howl", norm(reverb(bandpass(tone, 250, 2400), rng, 2.4, 0.5), 0.5))


def step(rng, idx, kind):
    n = int(SR * 0.18)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    if kind == "stone":
        x = bandpass(noise, 300, 3500) * np.exp(-t * 45)
        x += 0.5 * np.sin(2 * np.pi * rng.uniform(110, 160) * t) * np.exp(-t * 60)
    else:
        x = lowpass(noise, 900) * np.exp(-t * 30)
        grit = (rng.random(n) > 0.985) * rng.standard_normal(n) * np.exp(-t * 20)
        x += 0.6 * bandpass(grit, 1500, 6000)
    write_wav(f"step_{kind}_{idx}", norm(x, 0.55))


def fire(rng):
    n = SR * 8
    noise = rng.standard_normal(n)
    roar = lowpass(noise, 300) * 0.6
    crackle = np.zeros(n)
    for _ in range(140):
        p = int(rng.integers(0, n - 400))
        ln = int(rng.integers(40, 300))
        crackle[p:p + ln] += rng.standard_normal(ln) * np.exp(-np.arange(ln) / (ln / 4)) * rng.uniform(0.3, 1)
    write_wav("fire", norm(roar + bandpass(crackle, 1000, 7000), 0.6))


def pluck(freq: float, dur: float, rng, decay: float = 0.996) -> np.ndarray:
    """Karplus-Strong string: a lyre-like pluck."""
    n = int(SR * dur)
    period = max(2, int(round(SR / freq)))
    out = np.zeros(n)
    out[:period] = rng.uniform(-1, 1, period)
    for i in range(period, n):
        out[i] = decay * 0.5 * (out[i - period] + out[i - period - 1])
    return out * np.minimum(1, np.arange(n) / (SR * 0.004))


def reverb(x: np.ndarray, rng, seconds: float = 1.6, mix: float = 0.35) -> np.ndarray:
    n = int(SR * seconds)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / (SR * seconds / 5))
    wet = np.fft.irfft(np.fft.rfft(x, len(x) + n) * np.fft.rfft(ir, len(x) + n))[:len(x)]
    return x * (1 - mix) + norm(wet, np.max(np.abs(x))) * mix


def trailer_theme(rng):
    """31.5 s score for the trailer, following the day: D drone and lyre plucks in
    D Dorian by day, a second voice at sunset (11.2 s), a soft swell as night
    falls (16.6 s), a hush for the dream (22.2 s: plucks stop, the drone sinks
    an octave and breathes), a low hit on the hill reveal (25.4 s), a last
    chord, fade."""
    dur = 31.5
    n = int(SR * dur)
    t = np.arange(n) / SR
    out = np.zeros(n)

    def ramp(a, b):
        return np.clip((t - a) / (b - a), 0, 1)

    dream = ramp(22.0, 22.6) * (1 - ramp(25.2, 25.4))
    swell = ramp(0, 3.0) * (1 + 0.35 * ramp(11.2, 13.0) + 0.5 * ramp(16.4, 17.2) + 0.5 * ramp(25.4, 25.7)) \
        * (1 - 0.45 * dream) * np.clip((dur - t) / 2.0, 0, 1)
    drone = np.zeros(n)
    for f, a in ((73.42, 1.0), (110.0, 0.6), (146.83, 0.35)):
        ph = 2 * np.pi * f * t
        drone += a * (np.sin(ph) + 0.3 * np.sin(2 * ph) + 0.15 * np.sin(3 * ph))
    low = np.sin(2 * np.pi * 36.71 * t) * ramp(16.4, 18.0) * (1 + 0.8 * dream)
    drone = drone * (1 + 0.15 * np.sin(2 * np.pi * 0.25 * t)) + 0.8 * low
    out += lowpass(drone, 900) * swell * 0.33
    out += 0.5 * lowpass(rng.standard_normal(n), 250) * dream  # the dream breathes

    A3, C4, D4, E4, F4, G4, A4, C5, D5 = 220.0, 261.63, 293.66, 329.63, 349.23, 392.0, 440.0, 523.25, 587.33
    day = [(0.6, A4), (1.4, D5), (2.2, C5), (2.8, A4), (3.6, G4), (4.4, F4), (5.0, E4), (5.6, D4),
           (6.4, A4), (7.0, C5), (7.6, D5), (8.4, A4), (9.2, G4), (9.8, F4), (10.4, E4)]
    sunset = [(11.2, D4), (11.25, A4), (12.0, F4), (12.8, E4), (13.4, D4), (14.0, C4), (14.05, G4),
              (14.8, A4), (15.6, G4), (16.0, F4)]
    night = [(16.6, D4), (16.65, A4), (17.8, F4), (18.8, E4), (19.4, D4), (19.45, A3), (20.6, F4), (21.4, E4)]
    reveal = [(25.4, D4), (25.43, A4), (25.46, D5), (26.6, F4), (27.6, A4), (28.6, D5), (29.4, A3), (29.45, D4)]
    for group, gain in ((day, 0.6), (sunset, 0.65), (night, 0.45), (reveal, 0.85)):
        for start, f in group:
            p = pluck(f, 2.6, rng) * gain
            i = int(start * SR)
            j = min(n, i + len(p))
            out[i:j] += p[:j - i]
    # hits: a soft one as night falls, the low one on the hilltop reveal
    for at, gain, decay in ((16.6, 0.45, 3.0), (25.4, 0.95, 2.0)):
        i = int(at * SR)
        m = int(SR * 2.4)
        tt = np.arange(m) / SR
        hit = np.sin(2 * np.pi * (48 + 30 * np.exp(-tt * 8)) * tt) * np.exp(-tt * decay)
        hit += 0.5 * lowpass(rng.standard_normal(m), 400) * np.exp(-tt * 6)
        out[i:i + m] += hit[:n - i] * gain
    write_wav("trailer_theme", norm(reverb(out, rng), 0.8))


def main() -> None:
    for d in (TEX, MAT, AUD):
        d.mkdir(parents=True, exist_ok=True)
    for i, fn in enumerate(TEXTURES):
        fn(np.random.default_rng(1000 + i))
    materials()
    rng = np.random.default_rng(7)
    wind(rng)
    waves(rng)
    for i in range(3):
        gull(rng, i)
    for i in range(4):
        step(rng, i, "stone")
        step(rng, i, "dirt")
    fire(rng)
    trailer_theme(np.random.default_rng(77))
    # Separate generators: adding these must not change any existing asset.
    sky_dusk(np.random.default_rng(500))
    sky_night(np.random.default_rng(501))
    skin(np.random.default_rng(502))
    chiton(np.random.default_rng(503))
    hair(np.random.default_rng(504))
    mud(np.random.default_rng(505))
    net(np.random.default_rng(506))
    fish(np.random.default_rng(507))
    sand(np.random.default_rng(508))
    feather(np.random.default_rng(509))
    for i in range(3):
        cluck(np.random.default_rng(510 + i), i)
    squawk(np.random.default_rng(513))
    fleece(np.random.default_rng(514))
    dream_drone(np.random.default_rng(515))
    dog_howl(np.random.default_rng(516))
    worn(np.random.default_rng(517))
    fur(np.random.default_rng(518))
    print(f"textures: {len(TEXTURES)}, materials: {len(MATERIALS)}, audio: {len(list(AUD.glob('*.wav')))}")


if __name__ == "__main__":
    main()
