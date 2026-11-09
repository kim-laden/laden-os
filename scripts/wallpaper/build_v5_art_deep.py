#!/usr/bin/env python3
"""Laden OS Art v5 — 32K deep-zoom master (seam-free) + hidden hardware/CLI easter eggs.

v5 brief:
- LADEN letters only (no OS, no Let's do it) — source art already cleaned
- Soft feathered protect mask + continuous nebula (no hard rectangles / strip seams)
- Hidden emerald line-art hacking-hardware silhouettes (generic shapes, no logos)
- Tiny terminal CLI phrases along traces / grid / deep tunnel
- User-facing names: laden-os-art-v5-*
"""
from __future__ import annotations

import math
import shutil
import sys
from pathlib import Path

import numpy as np
import pyvips

_REPO = Path(__file__).resolve().parents[2]
OUT = _REPO / "build/wall-tmp/upscale"
DOCS = _REPO / "docs/wallpaper"
RELEASE = _REPO / "build/art-release/v5"
W, H = 30720, 17280
CX, CY = W * 0.505, H * 0.455
EMERALD = (0x2E, 0xE0, 0x7A)
TEAL = (0x1A, 0xC8, 0xB4)

pyvips.cache_set_max(32)
pyvips.cache_set_max_mem(128 * 1024 * 1024)
pyvips.cache_set_max_files(16)


def log(msg: str) -> None:
    print(msg, flush=True)


def hash01(x: int, y: int, salt: int = 0) -> float:
    n = (x * 374761393 + y * 668265263 + salt * 982451653) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return (n & 0xFFFFFF) / float(0xFFFFFF)


def save_strip_png(arr: np.ndarray, path: Path) -> None:
    h, w, c = arr.shape
    assert c == 3
    im = pyvips.Image.new_from_memory(arr.tobytes(), w, h, 3, "uchar")
    im.pngsave(str(path), compression=1)


def vips_join_vertical_simple(paths: list[Path], out: Path) -> None:
    if len(paths) == 1:
        im = pyvips.Image.new_from_file(str(paths[0]), access="sequential")
        im.tiffsave(str(out), tile=True, compression="lzw", tile_width=512, tile_height=512, bigtiff=True)
        return
    cur = OUT / "_join_cur.tif"
    im0 = pyvips.Image.new_from_file(str(paths[0]), access="sequential")
    im0.tiffsave(str(cur), tile=True, compression="lzw", tile_width=512, tile_height=512, bigtiff=True)
    for i, p in enumerate(paths[1:], 1):
        a = pyvips.Image.new_from_file(str(cur), access="sequential")
        b = pyvips.Image.new_from_file(str(p), access="sequential")
        j = a.join(b, "vertical")
        nxt = OUT / f"_join_next_{i}.tif"
        j.tiffsave(str(nxt), tile=True, compression="lzw", tile_width=512, tile_height=512, bigtiff=True)
        cur.unlink(missing_ok=True)
        cur = nxt
        log(f"  joined {i+1}/{len(paths)}")
        del a, b, j
    cur.rename(out)
    log(f"joined → {out.name} {out.stat().st_size/1e6:.1f} MB")


def gen_starfield_tiles(tile: int = 1024) -> Path:
    out = OUT / "v5-layer-stars-32k.tif"
    sdir = OUT / "strips-stars-v5"
    shutil.rmtree(sdir, ignore_errors=True)
    sdir.mkdir(parents=True)
    log(f"generating starfield → {out}")
    rng = np.random.default_rng(20261109)
    paths = []
    for y0 in range(0, H, tile):
        h = min(tile, H - y0)
        strip = np.zeros((h, W, 3), dtype=np.uint8)
        pops = [
            (1600, (1, 1), (35, 110), "teal"),
            (350, (1, 2), (90, 200), "white"),
            (55, (2, 3), (160, 255), "emerald"),
            (10, (3, 5), (200, 255), "emerald"),
        ]
        area_mp = (W * h) / 1_000_000.0
        for count_mp, (smin, smax), (bmin, bmax), colour in pops:
            n = int(count_mp * area_mp)
            xs = rng.integers(0, W, size=n)
            ys = rng.integers(0, h, size=n)
            sizes = rng.integers(smin, smax + 1, size=n)
            bris = rng.integers(bmin, bmax + 1, size=n)
            for i in range(n):
                x, y, sz, bri = int(xs[i]), int(ys[i]), int(sizes[i]), int(bris[i])
                dx = (x - CX) / W
                dy = ((y0 + y) - CY) / H
                if math.sqrt(dx * dx + dy * dy) < 0.12 and sz >= 3:
                    continue
                if colour == "teal":
                    col = (bri // 4, bri // 2 + 20, bri)
                elif colour == "emerald":
                    col = (int(bri * 0.18), bri, int(bri * 0.48))
                else:
                    col = (bri, bri, min(255, bri + 15))
                for oy in range(sz):
                    for ox in range(sz):
                        yy = y + oy - sz // 2
                        xx = x + ox - sz // 2
                        if 0 <= yy < h and 0 <= xx < W:
                            strip[yy, xx, 0] = max(strip[yy, xx, 0], col[0])
                            strip[yy, xx, 1] = max(strip[yy, xx, 1], col[1])
                            strip[yy, xx, 2] = max(strip[yy, xx, 2], col[2])
        step = 7
        for y in range(0, h, step):
            row = y0 + y
            for x in range(0, W, step):
                if hash01(x, row, 7) > 0.965:
                    bri = int(18 + 50 * hash01(x, row, 9))
                    strip[y, x, 1] = max(strip[y, x, 1], bri)
                    strip[y, x, 2] = max(strip[y, x, 2], bri // 2)
        p = sdir / f"s-{y0:05d}.png"
        save_strip_png(strip, p)
        paths.append(p)
        del strip
        log(f"  star strip y={y0}..{y0+h}")
    try:
        vips_join_vertical_simple(paths, out)
    finally:
        shutil.rmtree(sdir, ignore_errors=True)
    return out


def _value_noise(w: int, h: int, scale: int, seed: int) -> np.ndarray:
    gw = max(2, w // scale + 2)
    gh = max(2, h // scale + 2)
    rng = np.random.default_rng(seed)
    grid = rng.random((gh, gw), dtype=np.float32)
    im = pyvips.Image.new_from_memory(grid.tobytes(), gw, gh, 1, "float")
    im = im.resize(w / (gw - 1), vscale=h / (gh - 1), kernel="linear").crop(0, 0, w, h)
    return np.frombuffer(im.write_to_memory(), dtype=np.float32).reshape(h, w)


def gen_nebula_layer() -> Path:
    out = OUT / "v5-layer-nebula-32k.tif"
    log(f"generating continuous nebula → {out}")
    sw, sh = 1920, 1080
    n = np.zeros((sh, sw), dtype=np.float32)
    for oi, (sc, amp) in enumerate([(64, 0.42), (32, 0.28), (16, 0.16), (8, 0.09), (4, 0.05)]):
        n += amp * _value_noise(sw, sh, sc, seed=20261109 + oi * 17)
    n = (n - float(n.mean())) / (float(n.std()) + 1e-6)
    n = np.clip(n * 0.38 + 0.42, 0.0, 1.0).astype(np.float32)
    yy = np.linspace(0, 1, sh, dtype=np.float32)[:, None]
    xx = np.linspace(0, 1, sw, dtype=np.float32)[None, :]
    dx = xx - 0.505
    dy = yy - 0.455
    rad = np.sqrt(dx * dx + dy * dy)
    weight = np.clip(0.15 + 0.9 * rad, 0, 1) * np.clip(1.1 - yy * 0.35, 0.4, 1)
    n *= weight.astype(np.float32)
    rgb = np.zeros((sh, sw, 3), dtype=np.float32)
    rgb[..., 0] = n * 0.08
    rgb[..., 1] = n * 0.55 + n * n * 0.25
    rgb[..., 2] = n * 0.38
    rgb_u8 = np.clip(rgb * 255.0, 0, 180).astype(np.uint8)
    im = pyvips.Image.new_from_memory(rgb_u8.tobytes(), sw, sh, 3, "uchar").gaussblur(1.2)
    full = im.resize(W / sw, vscale=H / sh, kernel="linear")
    if full.width != W or full.height != H:
        full = full.embed(0, 0, W, H, extend="black").crop(0, 0, W, H)
    full.tiffsave(str(out), tile=True, compression="lzw", tile_width=512, tile_height=512, bigtiff=True)
    log(f"nebula done {out.stat().st_size/1e6:.1f} MB")
    return out


# --- Tiny 3x5 font for CLI microtext (half-res coords) ---
FONT3 = {
    "0": ["111", "101", "101", "101", "111"],
    "1": ["010", "110", "010", "010", "111"],
    "2": ["111", "001", "111", "100", "111"],
    "3": ["111", "001", "111", "001", "111"],
    "4": ["101", "101", "111", "001", "001"],
    "5": ["111", "100", "111", "001", "111"],
    "6": ["111", "100", "111", "101", "111"],
    "7": ["111", "001", "010", "010", "010"],
    "8": ["111", "101", "111", "101", "111"],
    "9": ["111", "101", "111", "001", "111"],
    "a": ["010", "101", "111", "101", "101"],
    "b": ["110", "101", "110", "101", "110"],
    "c": ["011", "100", "100", "100", "011"],
    "d": ["110", "101", "101", "101", "110"],
    "e": ["111", "100", "111", "100", "111"],
    "f": ["111", "100", "111", "100", "100"],
    "g": ["011", "100", "101", "101", "011"],
    "h": ["101", "101", "111", "101", "101"],
    "i": ["010", "000", "010", "010", "010"],
    "j": ["001", "001", "001", "101", "010"],
    "k": ["101", "101", "110", "101", "101"],
    "l": ["100", "100", "100", "100", "111"],
    "m": ["101", "111", "111", "101", "101"],
    "n": ["101", "111", "111", "101", "101"],
    "o": ["111", "101", "101", "101", "111"],
    "p": ["111", "101", "111", "100", "100"],
    "q": ["111", "101", "111", "001", "001"],
    "r": ["111", "101", "110", "101", "101"],
    "s": ["011", "100", "010", "001", "110"],
    "t": ["111", "010", "010", "010", "010"],
    "u": ["101", "101", "101", "101", "111"],
    "v": ["101", "101", "101", "101", "010"],
    "w": ["101", "101", "111", "111", "101"],
    "x": ["101", "101", "010", "101", "101"],
    "y": ["101", "101", "010", "010", "010"],
    "z": ["111", "001", "010", "100", "111"],
    "A": ["010", "101", "111", "101", "101"],
    "B": ["110", "101", "110", "101", "110"],
    "C": ["011", "100", "100", "100", "011"],
    "D": ["110", "101", "101", "101", "110"],
    "E": ["111", "100", "111", "100", "111"],
    "F": ["111", "100", "111", "100", "100"],
    "G": ["011", "100", "101", "101", "011"],
    "H": ["101", "101", "111", "101", "101"],
    "I": ["111", "010", "010", "010", "111"],
    "J": ["001", "001", "001", "101", "010"],
    "K": ["101", "110", "100", "110", "101"],
    "L": ["100", "100", "100", "100", "111"],
    "M": ["101", "111", "111", "101", "101"],
    "N": ["101", "111", "111", "101", "101"],
    "O": ["111", "101", "101", "101", "111"],
    "P": ["111", "101", "111", "100", "100"],
    "Q": ["111", "101", "101", "111", "001"],
    "R": ["111", "101", "110", "101", "101"],
    "S": ["011", "100", "010", "001", "110"],
    "T": ["111", "010", "010", "010", "010"],
    "U": ["101", "101", "101", "101", "111"],
    "V": ["101", "101", "101", "101", "010"],
    "W": ["101", "101", "111", "111", "101"],
    "X": ["101", "101", "010", "101", "101"],
    "Y": ["101", "101", "010", "010", "010"],
    "Z": ["111", "001", "010", "100", "111"],
    "-": ["000", "000", "111", "000", "000"],
    "_": ["000", "000", "000", "000", "111"],
    ".": ["000", "000", "000", "000", "010"],
    ",": ["000", "000", "000", "010", "100"],
    ":": ["000", "010", "000", "010", "000"],
    "/": ["001", "010", "010", "010", "100"],
    "\\": ["100", "010", "010", "010", "001"],
    "@": ["010", "101", "111", "100", "011"],
    " ": ["000", "000", "000", "000", "000"],
    "'": ["010", "010", "000", "000", "000"],
    "!": ["010", "010", "010", "000", "010"],
    "`": ["100", "010", "000", "000", "000"],
    "=": ["000", "111", "000", "111", "000"],
    "+": ["000", "010", "111", "010", "000"],
    "*": ["101", "010", "111", "010", "101"],
    "(": ["001", "010", "010", "010", "001"],
    ")": ["100", "010", "010", "010", "100"],
    "[": ["111", "100", "100", "100", "111"],
    "]": ["111", "001", "001", "001", "111"],
    "{": ["011", "010", "110", "010", "011"],
    "}": ["110", "010", "011", "010", "110"],
    "|": ["010", "010", "010", "010", "010"],
    "<": ["001", "010", "100", "010", "001"],
    ">": ["100", "010", "001", "010", "100"],
    "#": ["101", "111", "101", "111", "101"],
    "$": ["010", "111", "110", "011", "010"],
    "%": ["101", "001", "010", "100", "101"],
    "^": ["010", "101", "000", "000", "000"],
    "&": ["010", "101", "010", "101", "011"],
    "~": ["000", "011", "100", "000", "000"],
    "?": ["111", "001", "010", "000", "010"],
}


def text_pixels(text: str, x0: int, y0: int, scale: int = 1):
    """Yield (x,y) pixels for tiny bitmap text."""
    x = x0
    for ch in text:
        glyph = FONT3.get(ch, FONT3.get(ch.lower(), FONT3[" "]))
        for row, bits in enumerate(glyph):
            for col, bit in enumerate(bits):
                if bit == "1":
                    for sy in range(scale):
                        for sx in range(scale):
                            yield (x + col * scale + sx, y0 + row * scale + sy)
        x += (3 * scale + 1)


# Hardware silhouette polylines in local unit coords (-0.5..0.5), then scaled.
# Generic shapes only — no logos/wordmarks.
HARDWARE = [
    # name, (fx, fy) fractions of half-res frame, scale px, polylines list of [(x,y),...]
    ("flipper-zero", 0.18, 0.62, 28, [
        [(-0.45, -0.25), (0.45, -0.25), (0.45, 0.30), (-0.45, 0.30), (-0.45, -0.25)],  # body
        [(-0.30, -0.15), (0.10, -0.15), (0.10, 0.05), (-0.30, 0.05), (-0.30, -0.15)],  # screen
        [(0.20, -0.05), (0.35, -0.05), (0.35, 0.10), (0.20, 0.10), (0.20, -0.05)],  # d-pad box
        [(0.00, -0.40), (0.00, -0.25)],  # antenna stub
    ]),
    ("wifi-pineapple-mk7", 0.48, 0.78, 22, [
        [(-0.35, 0.05), (0.35, 0.05), (0.35, 0.35), (-0.35, 0.35), (-0.35, 0.05)],  # body
        [(-0.25, 0.05), (-0.25, -0.45)],  # ant1
        [(0.00, 0.05), (0.00, -0.50)],   # ant2
        [(0.25, 0.05), (0.25, -0.45)],   # ant3
        [(-0.25, -0.45), (-0.20, -0.40)],
        [(0.00, -0.50), (0.05, -0.45)],
        [(0.25, -0.45), (0.30, -0.40)],
    ]),
    ("usb-rubber-ducky", 0.12, 0.72, 18, [
        [(-0.40, -0.15), (0.25, -0.15), (0.25, 0.15), (-0.40, 0.15), (-0.40, -0.15)],
        [(0.25, -0.10), (0.45, -0.10), (0.45, 0.10), (0.25, 0.10)],  # USB plug
        [(-0.25, -0.05), (-0.05, -0.05)],
    ]),
    ("hackrf-one", 0.78, 0.68, 26, [
        [(-0.40, -0.25), (0.40, -0.25), (0.40, 0.25), (-0.40, 0.25), (-0.40, -0.25)],
        [(-0.25, -0.40), (-0.25, -0.25)],  # SMA1
        [(0.00, -0.40), (0.00, -0.25)],    # SMA2
        [(0.25, -0.40), (0.25, -0.25)],    # SMA3
        [(-0.15, -0.10), (0.15, -0.10), (0.15, 0.10), (-0.15, 0.10), (-0.15, -0.10)],  # chip
    ]),
    ("proxmark3", 0.28, 0.82, 24, [
        [(-0.35, -0.20), (0.35, -0.20), (0.35, 0.20), (-0.35, 0.20), (-0.35, -0.20)],
        # antenna loop
        [(-0.15, -0.45), (0.15, -0.45), (0.25, -0.30), (0.15, -0.15), (-0.15, -0.15), (-0.25, -0.30), (-0.15, -0.45)],
        [(0.35, 0.00), (0.48, 0.00)],  # USB
    ]),
    ("lan-turtle", 0.85, 0.80, 16, [
        [(-0.30, -0.20), (0.10, -0.20), (0.10, 0.20), (-0.30, 0.20), (-0.30, -0.20)],
        [(0.10, -0.12), (0.40, -0.12), (0.40, 0.12), (0.10, 0.12)],  # RJ45-ish
        [(-0.45, -0.08), (-0.30, -0.08), (-0.30, 0.08), (-0.45, 0.08)],  # USB
    ]),
    ("bash-bunny", 0.15, 0.55, 18, [
        [(-0.35, -0.18), (0.20, -0.18), (0.20, 0.18), (-0.35, 0.18), (-0.35, -0.18)],
        [(0.20, -0.12), (0.42, -0.12), (0.42, 0.12), (0.20, 0.12)],
        [(-0.20, -0.08), (-0.05, -0.08)],
        [(-0.20, 0.00), (-0.05, 0.00)],
        [(-0.20, 0.08), (-0.05, 0.08)],
    ]),
    ("omg-cable", 0.62, 0.85, 30, [
        [(-0.45, 0.00), (-0.20, 0.00), (-0.10, -0.08), (0.10, 0.08), (0.20, 0.00), (0.45, 0.00)],  # cable curve
        [(-0.50, -0.08), (-0.40, -0.08), (-0.40, 0.08), (-0.50, 0.08), (-0.50, -0.08)],  # end A
        [(0.40, -0.08), (0.50, -0.08), (0.50, 0.08), (0.40, 0.08), (0.40, -0.08)],  # end B
    ]),
    ("esp32-nugget", 0.72, 0.58, 16, [
        [(-0.30, -0.25), (0.30, -0.25), (0.30, 0.25), (-0.30, 0.25), (-0.30, -0.25)],
        [(0.00, -0.45), (0.00, -0.25)],  # antenna
        [(-0.15, -0.10), (0.15, -0.10), (0.15, 0.10), (-0.15, 0.10), (-0.15, -0.10)],
        [(-0.20, 0.25), (-0.20, 0.35)],
        [(0.00, 0.25), (0.00, 0.35)],
        [(0.20, 0.25), (0.20, 0.35)],
    ]),
]

CLI_PHRASES = [
    ("nmap -sV -A", 0.22, 0.70),
    ("msfconsole", 0.58, 0.74),
    ("use exploit/multi/handler", 0.40, 0.86),
    ("aircrack-ng", 0.70, 0.72),
    ("hashcat -m 22000", 0.33, 0.90),
    ("john --wordlist", 0.80, 0.64),
    ("sqlmap -u", 0.16, 0.84),
    ("hydra -l", 0.88, 0.76),
    ("nc -lvnp 4444", 0.50, 0.92),
    ("sudo pacman -Syu", 0.25, 0.50),
    ("whoami", 0.66, 0.52),
    ("uname -a", 0.10, 0.48),
    ("ssh root@", 0.90, 0.55),
    ("tcpdump -i", 0.42, 0.66),
    ("gobuster dir", 0.75, 0.88),
    ("0x41414141", 0.55, 0.60),
    ("It's not a bug", 0.35, 0.58),
    ("Hack the planet", 0.48, 0.95),
]


def gen_hex_circuit_layer() -> Path:
    out = OUT / "v5-layer-hex-32k.tif"
    rw, rh = W // 2, H // 2
    log(f"generating hex/circuit + hardware/CLI → {out}")
    sdir = OUT / "strips-hex-v5"
    shutil.rmtree(sdir, ignore_errors=True)
    sdir.mkdir()
    tile = 864
    rcx, rcy = CX / 2, CY / 2

    segs = []
    nodes = []

    def add_line(x0, y0, x1, y1, col, a):
        segs.append((x0, y0, x1, y1, col[0], col[1], col[2], a))

    log("  compute hex lattice…")
    for gy in range(-40, 80):
        for gx in range(-60, 61):
            hx = 1.5 * gx
            hy = math.sqrt(3) * (gy + 0.5 * (gx & 1))
            wx = hx * 28.0
            wz = 40 + hy * 28.0
            if wz < 8:
                continue
            scale = 4200.0
            sx = rcx + (wx / wz) * scale
            sy = rcy + (1.15 * scale) / wz * 0.85 + (rh * 0.08)
            if sy < rcy - 80:
                if hash01(gx, gy, 3) > 0.82:
                    nodes.append((sx, sy - (rcy - sy) * 0.3, TEAL[0], TEAL[1], TEAL[2], 0.15))
                continue
            edge = max(2.0, 55.0 / (wz / 40.0))
            alpha = float(np.clip(0.15 + 80.0 / wz, 0.12, 0.55))
            col = (int(EMERALD[0] * 0.7), int(EMERALD[1] * 0.7), int(EMERALD[2] * 0.7))
            for k in range(6):
                a0 = math.radians(60 * k)
                a1 = math.radians(60 * (k + 1))
                add_line(
                    sx + edge * math.cos(a0), sy + edge * math.sin(a0) * 0.55,
                    sx + edge * math.cos(a1), sy + edge * math.sin(a1) * 0.55,
                    col, alpha,
                )

    log("  compute circuits…")
    rng = np.random.default_rng(42)
    for i in range(220):
        ang = rng.uniform(-math.pi, math.pi)
        dist0 = rng.uniform(180, min(rw, rh) * 0.7)
        x = rcx + math.cos(ang) * dist0
        y = rcy + math.sin(ang) * dist0 * 0.62
        steps = int(rng.integers(8, 28))
        col = EMERALD if rng.random() > 0.35 else TEAL
        a = float(rng.uniform(0.25, 0.55))
        for s in range(steps):
            if rng.random() < 0.35:
                ang += rng.choice([-1.0, 1.0]) * math.pi / 2 * rng.uniform(0.3, 1.0)
            step = float(rng.uniform(8, 28))
            x2 = x + math.cos(ang) * step * (-0.35)
            y2 = y + math.sin(ang) * step * (-0.35) * 0.7
            x2 = x2 * 0.85 + rcx * 0.15
            y2 = y2 * 0.85 + rcy * 0.15
            add_line(x, y, x2, y2, col, a)
            if rng.random() < 0.2:
                nodes.append((x2, y2, col[0], col[1], col[2], a))
            x, y = x2, y2
            if math.hypot(x - rcx, y - rcy) < 90:
                break

    # Classic text eggs + CLI phrases
    egg_pixels = []
    text_eggs = [
        ("laden.no", int(rw * 0.12), int(rh * 0.18), 1),
        ("0101", int(rw * 0.20), int(rh * 0.80), 1),
        ("L", int(rw * 0.88), int(rh * 0.72), 1),
        ("laden", int(rw * 0.55), int(rh * 0.88), 1),
    ]
    for text, x0, y0, sc in text_eggs:
        for x, y in text_pixels(text, x0, y0, sc):
            egg_pixels.append((x, y, EMERALD[0], EMERALD[1], EMERALD[2], 0.9))

    cli_meta = []
    for text, fx, fy in CLI_PHRASES:
        x0, y0 = int(rw * fx), int(rh * fy)
        # deep tunnel phrases slightly dimmer
        a = 0.55 if fy > 0.85 else 0.75
        for x, y in text_pixels(text, x0, y0, 1):
            egg_pixels.append((x, y, TEAL[0], TEAL[1], TEAL[2], a))
        cli_meta.append((text, x0 * 2, y0 * 2))  # 32K coords

    # Hardware silhouettes → line segments
    hw_meta = []
    for name, fx, fy, sc, polys in HARDWARE:
        cx, cy = rw * fx, rh * fy
        hw_meta.append((name, int(cx * 2), int(cy * 2), sc * 2))
        for poly in polys:
            pts = [(cx + px * sc, cy + py * sc) for px, py in poly]
            for i in range(len(pts) - 1):
                add_line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], EMERALD, 0.70)
            # close if first≈last already handled by explicit close in data

    log(f"  segs={len(segs)} nodes={len(nodes)} eggs={len(egg_pixels)} hw={len(HARDWARE)} cli={len(CLI_PHRASES)}")

    def raster_strip(y0: int, h: int) -> np.ndarray:
        img = np.zeros((h, rw, 3), dtype=np.uint8)

        def plot(x, y, col, a=1.0):
            xi, yi = int(x), int(y)
            if 0 <= xi < rw and 0 <= yi < h:
                for c in range(3):
                    img[yi, xi, c] = min(255, int(img[yi, xi, c] * (1 - a) + col[c] * a))

        def draw_line(x0_, y0_, x1_, y1_, col, a, step=0.65):
            dx, dy = x1_ - x0_, y1_ - y0_
            L = math.hypot(dx, dy) or 1
            n = max(1, int(L / step))
            for i in range(n + 1):
                t = i / n
                x = x0_ + dx * t
                y = y0_ + dy * t - y0
                plot(x, y, col, a)

        y1 = y0 + h
        for x0_, y0_, x1_, y1_, r, g, b, a in segs:
            if max(y0_, y1_) < y0 - 2 or min(y0_, y1_) > y1 + 2:
                continue
            draw_line(x0_, y0_, x1_, y1_, (r, g, b), a)
        for x, y, r, g, b, a in nodes:
            if y0 - 2 <= y < y1 + 2:
                for t in range(-1, 2):
                    for u in range(-1, 2):
                        plot(x + t, y + u - y0, (r, g, b), a)
        for x, y, r, g, b, a in egg_pixels:
            if y0 <= y < y1:
                plot(x, y - y0, (r, g, b), a)
        return img

    paths = []
    for y0 in range(0, rh, tile):
        h = min(tile, rh - y0)
        arr = raster_strip(y0, h)
        p = sdir / f"h-{y0:05d}.png"
        save_strip_png(arr, p)
        paths.append(p)
        del arr
        log(f"  hex strip y={y0}..{y0+h}")

    half = OUT / "v5-layer-hex-half.tif"
    vips_join_vertical_simple(paths, half)
    shutil.rmtree(sdir, ignore_errors=True)
    log("  nearest-upscale hex to 32K…")
    full = pyvips.Image.new_from_file(str(half), access="sequential").resize(2.0, kernel="nearest")
    if full.width != W or full.height != H:
        full = full.embed(0, 0, W, H, extend="black").crop(0, 0, W, H)
    full.tiffsave(str(out), tile=True, compression="lzw", tile_width=512, tile_height=512, bigtiff=True)
    half.unlink(missing_ok=True)
    log(f"hex done {out.stat().st_size/1e6:.1f} MB")

    lines = [f"{n}:{x},{y}:{s}" for n, x, y, s in hw_meta]
    (OUT / "v5-hardware-eggs.txt").write_text("\n".join(lines) + "\n")
    (OUT / "v5-cli-eggs.txt").write_text("\n".join(f"{t}:{x},{y}" for t, x, y in cli_meta) + "\n")
    (OUT / "v5-easter-eggs.txt").write_text(
        "\n".join(f"{t}:{x*2},{y*2}" for t, x, y, _ in [
            ("laden.no", int(rw * 0.12), int(rh * 0.18), 1),
            ("0101", int(rw * 0.20), int(rh * 0.80), 1),
            ("L", int(rw * 0.88), int(rh * 0.72), 1),
        ]) + "\n"
    )
    return out


def _soft_blob(reg: np.ndarray, cy: float, cx: float, ry: float, rx: float, strength: float = 1.0) -> None:
    rh, rw = reg.shape
    yy = np.arange(rh, dtype=np.float32)[:, None]
    xx = np.arange(rw, dtype=np.float32)[None, :]
    d = ((yy - cy) / max(ry, 1e-3)) ** 2 + ((xx - cx) / max(rx, 1e-3)) ** 2
    blob = np.exp(-0.5 * d) * strength
    np.maximum(reg, blob, out=reg)


def make_protect_mask_from_base(base8k_path: Path) -> Path:
    """Soft protect — LADEN letters / planet / rocket / icons only (no OS/tagline boxes)."""
    out = OUT / "v5-protect-mask-32k.tif"
    log("building soft protect mask (v5)…")
    im = pyvips.Image.new_from_file(str(base8k_path), access="sequential")
    lum = im.bandmean()
    r, g, b = im[0], im[1], im[2]
    greenish = (g > r * 1.05) & (g > b * 0.9) & (g > 40)
    bright = lum > 55
    protect = (greenish | bright).ifthenelse(255, 0).gaussblur(10).cast("uchar")
    protect = (protect > 12).ifthenelse(protect, 0)

    w8, h8 = im.width, im.height
    rw, rh = 960, 540
    reg = np.zeros((rh, rw), dtype=np.float32)
    # LADEN letters only (no OS / tagline region)
    _soft_blob(reg, 0.44 * rh, 0.50 * rw, 0.18 * rh, 0.36 * rw, 1.0)
    # Planet
    _soft_blob(reg, 0.90 * rh, 0.12 * rw, 0.22 * rh, 0.20 * rw, 1.0)
    # Rocket + plume
    _soft_blob(reg, 0.18 * rh, 0.90 * rw, 0.16 * rh, 0.10 * rw, 0.95)
    _soft_blob(reg, 0.28 * rh, 0.90 * rw, 0.10 * rh, 0.06 * rw, 0.7)
    # Icons
    for fy in (0.32, 0.48, 0.62):
        _soft_blob(reg, fy * rh, 0.07 * rw, 0.07 * rh, 0.05 * rw, 0.85)
    for fy, fx in ((0.30, 0.93), (0.48, 0.93), (0.78, 0.90)):
        _soft_blob(reg, fy * rh, fx * rw, 0.07 * rh, 0.05 * rw, 0.85)

    reg_img = pyvips.Image.new_from_memory(reg.tobytes(), rw, rh, 1, "float")
    reg_img = reg_img.gaussblur(28)
    reg_img = (reg_img > 1.0).ifthenelse(1.0, reg_img)
    reg_img = (reg_img < 0.0).ifthenelse(0.0, reg_img)
    reg_img = reg_img.resize(w8 / rw, vscale=h8 / rh, kernel="linear")
    reg_u8 = (reg_img * 255).cast("uchar")
    combined = (protect > reg_u8).ifthenelse(protect, reg_u8).gaussblur(6)
    combined32 = combined.resize(W / w8, vscale=H / h8, kernel="linear").cast("uchar")
    combined32 = combined32.gaussblur(18).cast("uchar")
    combined32.tiffsave(str(out), tile=True, compression="lzw", tile_width=512, tile_height=512, bigtiff=True)
    log(f"soft mask {out.stat().st_size/1e6:.1f} MB")
    del combined32, combined, protect, reg_img, im
    prev = pyvips.Image.new_from_file(str(out), access="sequential").resize(1920 / W, vscale=1080 / H, kernel="linear")
    prev.jpegsave(str(DOCS / "v5-protect-mask-preview.jpg"), Q=85)
    return out


def blend_all(ai_path: Path, stars: Path, nebula: Path, hexpath: Path, mask: Path, out_png: Path) -> None:
    log("blending in strips…")
    sdir = OUT / "strips-blend-v5"
    shutil.rmtree(sdir, ignore_errors=True)
    sdir.mkdir()
    tile = 512
    paths = []
    base = pyvips.Image.new_from_file(str(ai_path), access="random")
    if base.bands > 3:
        base = base.extract_band(0, n=3)
    st = pyvips.Image.new_from_file(str(stars), access="random")
    nb = pyvips.Image.new_from_file(str(nebula), access="random")
    hx = pyvips.Image.new_from_file(str(hexpath), access="random")
    pr = pyvips.Image.new_from_file(str(mask), access="random")
    if pr.bands > 1:
        pr = pr.extract_band(0)

    for y0 in range(0, H, tile):
        h = min(tile, H - y0)
        b = base.crop(0, y0, W, h)
        s = st.crop(0, y0, W, h)
        n = nb.crop(0, y0, W, h)
        x = hx.crop(0, y0, W, h)
        p = pr.crop(0, y0, W, h)
        bf = b / 255.0
        sf = s / 255.0
        nf = n / 255.0
        xf = x / 255.0
        pf = p / 255.0
        detail = 1.0 - pf
        screened = 1.0 - (1.0 - bf) * (1.0 - sf * 0.80)
        soft = 1.0 - (1.0 - screened) * (1.0 - nf * 0.45)
        enhanced = soft + xf * 0.70
        enhanced = (enhanced > 1.0).ifthenelse(1.0, enhanced)
        enhanced = (enhanced < 0.0).ifthenelse(0.0, enhanced)
        final = bf * pf + enhanced * detail
        final = (final > 1.0).ifthenelse(1.0, final)
        final = (final < 0.0).ifthenelse(0.0, final)
        out = (final * 255).cast("uchar")
        if out.bands > 3:
            out = out.extract_band(0, n=3)
        pth = sdir / f"b-{y0:05d}.png"
        out.pngsave(str(pth), compression=1)
        paths.append(pth)
        if (y0 // tile) % 8 == 0:
            log(f"  blend y={y0}")
    mid = OUT / "v5-deep-master-mid.tif"
    vips_join_vertical_simple(paths, mid)
    shutil.rmtree(sdir, ignore_errors=True)
    log("writing final 32K PNG…")
    master = pyvips.Image.new_from_file(str(mid), access="sequential")
    master.pngsave(str(out_png), compression=4)
    log(f"master PNG {out_png.stat().st_size/1e6:.1f} MB")
    mid.unlink(missing_ok=True)


def downscale_set(master_path: Path, stem: str) -> dict:
    outs = {}
    for w, h in [(7680, 4320), (3840, 2160), (2560, 1440), (1920, 1080)]:
        log(f"downscale {w}x{h}")
        master = pyvips.Image.new_from_file(str(master_path), access="sequential")
        im = master.resize(w / master.width, vscale=h / master.height, kernel="lanczos3")
        p = OUT / f"{stem}-{w}x{h}.png"
        im.pngsave(str(p), compression=9)
        outs[f"{w}x{h}"] = p
    log("downscale 3440x1440")
    master = pyvips.Image.new_from_file(str(master_path), access="sequential")
    im = master.resize(3440 / master.width, kernel="lanczos3")
    top = max(0, (im.height - 1440) // 2)
    im = im.crop(0, top, 3440, 1440)
    p = OUT / f"{stem}-3440x1440.png"
    im.pngsave(str(p), compression=9)
    outs["3440x1440"] = p
    return outs


def phone_crops(master_path: Path, stem: str) -> dict:
    """Center-weighted portrait crops for phone wallpapers."""
    outs = {}
    master = pyvips.Image.new_from_file(str(master_path), access="random")
    for tw, th in [(1290, 2796), (1440, 3200)]:
        # Scale so height fills, then center-crop width (slightly biased toward letters)
        scale = th / master.height
        im = master.resize(scale, kernel="lanczos3")
        if im.width < tw:
            scale = tw / master.width
            im = master.resize(scale, kernel="lanczos3")
        left = max(0, int((im.width - tw) * 0.48))  # slight left bias keeps planet
        top = max(0, (im.height - th) // 2)
        im = im.crop(left, top, min(tw, im.width), min(th, im.height))
        if im.width != tw or im.height != th:
            im = im.embed(0, 0, tw, th, extend="black")
        p = OUT / f"{stem}-{tw}x{th}.png"
        im.pngsave(str(p), compression=9)
        outs[f"{tw}x{th}"] = p
        log(f"phone crop {tw}x{th}")
    return outs


def zoom_crops(master_path: Path) -> None:
    DOCS.mkdir(parents=True, exist_ok=True)
    im = pyvips.Image.new_from_file(str(master_path), access="random")
    # Hardware zoom showing 2-3 devices (flipper + pineapple + ducky area)
    crops = {
        "v5-zoom-hardware-left.png": (int(W * 0.08), int(H * 0.48), 1800, 1400),
        "v5-zoom-hardware-tunnel.png": (int(W * 0.38), int(H * 0.70), 1600, 1200),
        "v5-zoom-cli-floor.png": (int(W * 0.30), int(H * 0.82), 1600, 1000),
        "v5-zoom-logo-edge.png": (int(W * 0.40), int(H * 0.36), 1200, 800),
        "v5-zoom-fix-rocket-tr.png": (int(W * 0.74), int(H * 0.02), 1600, 1200),
        "v5-zoom-fix-left-edge.png": (int(W * 0.00), int(H * 0.28), 900, 1400),
    }
    for name, (x, y, w, h) in crops.items():
        x = max(0, min(x, W - w))
        y = max(0, min(y, H - h))
        im.crop(x, y, w, h).pngsave(str(DOCS / name), compression=6)
        log(f"crop {name}")
    im.resize(1920 / W, kernel="lanczos3").jpegsave(str(DOCS / "laden-os-art-v5-preview-1920x1080.jpg"), Q=90)


def build_release_pack(master: Path, downs: dict, phones: dict) -> Path:
    RELEASE.mkdir(parents=True, exist_ok=True)
    mapping = {
        "laden-os-art-v5-deep-30720x17280.png": master,
        "laden-os-art-v5-7680x4320.png": downs["7680x4320"],
        "laden-os-art-v5-3840x2160.png": downs["3840x2160"],
        "laden-os-art-v5-3440x1440.png": downs["3440x1440"],
        "laden-os-art-v5-2560x1440.png": downs["2560x1440"],
        "laden-os-art-v5-1920x1080.png": downs["1920x1080"],
        "laden-os-art-v5-1290x2796.png": phones["1290x2796"],
        "laden-os-art-v5-1440x3200.png": phones["1440x3200"],
    }
    for name, src in mapping.items():
        dst = RELEASE / name
        if dst.exists():
            dst.unlink()
        shutil.copy2(src, dst)
        log(f"release {name} {dst.stat().st_size/1e6:.1f} MB")

    hw = (OUT / "v5-hardware-eggs.txt").read_text() if (OUT / "v5-hardware-eggs.txt").exists() else ""
    cli = (OUT / "v5-cli-eggs.txt").read_text() if (OUT / "v5-cli-eggs.txt").exists() else ""
    readme = RELEASE / "README.md"
    readme.write_text(
        f"""# Laden OS Art v5

Calm emerald grid-tunnel art for Laden OS. Large LADEN letters, deeper tunnel under the logo (no \"OS\" / no \"Let's do it!\").

## Files
| File | Size |
|------|------|
| laden-os-art-v5-deep-30720x17280.png | 32K deep-zoom master |
| laden-os-art-v5-7680x4320.png | 8K |
| laden-os-art-v5-3840x2160.png | 4K |
| laden-os-art-v5-3440x1440.png | Ultrawide |
| laden-os-art-v5-2560x1440.png | QHD |
| laden-os-art-v5-1920x1080.png | FHD |
| laden-os-art-v5-1290x2796.png | Phone |
| laden-os-art-v5-1440x3200.png | Phone |

## Hidden details (zoom in)
Emerald neon line-art silhouettes (generic shapes, no vendor logos/wordmarks):
{hw}

Tiny terminal phrases along traces / floor / deep tunnel:
{cli}

Also: laden.no, 0101, tiny L.

## Credits
Art direction: Laden AS / Laden OS  
Pipeline: Real-ESRGAN (realesrgan-x4plus-anime) + procedural pyvips layers (stars, nebula, hex/circuit, soft protect mask)

## License
LicenseRef-LadenAS — placeholder. Contact Laden AS (https://laden.no) for redistribution terms.
This pack is prepared locally and is NOT published.

## Verify
```
sha256sum -c SHA256SUMS
```
"""
    )
    # sha256sums
    import hashlib
    lines = []
    for name in sorted(mapping.keys()) + ["README.md"]:
        p = RELEASE / name
        h = hashlib.sha256(p.read_bytes()).hexdigest()
        lines.append(f"{h}  {name}")
    (RELEASE / "SHA256SUMS").write_text("\n".join(lines) + "\n")

    zip_path = RELEASE.parent / "Laden-OS-Art-v5.zip"
    if zip_path.exists():
        zip_path.unlink()
    import zipfile
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for p in sorted(RELEASE.iterdir()):
            zf.write(p, arcname=f"Laden-OS-Art-v5/{p.name}")
    log(f"zip {zip_path} {zip_path.stat().st_size/1e6:.1f} MB")
    return zip_path


def seam_qc(preview_jpg: Path) -> None:
    log("seam QC…")
    im = pyvips.Image.new_from_file(str(preview_jpg))
    lum = im.bandmean().cast("float")
    gx = lum.conv(pyvips.Image.new_from_array([[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]], scale=1))
    gy = lum.conv(pyvips.Image.new_from_array([[-1, -2, -1], [0, 0, 0], [1, 2, 1]], scale=1))
    mag = ((gx * gx + gy * gy) ** 0.5)
    (mag * 3).cast("uchar").jpegsave(str(DOCS / "v5-seam-edge-map.jpg"), Q=90)
    arr = np.frombuffer(im.write_to_memory(), dtype=np.uint8).reshape(im.height, im.width, im.bands)
    lum_a = arr.mean(axis=2)
    tr = lum_a[0:int(0.31 * 1080), int(0.77 * 1920) :]
    adj = lum_a[0:int(0.31 * 1080), int(0.60 * 1920) : int(0.75 * 1920)]
    le = lum_a[int(0.26 * 1080) : int(0.75 * 1080), 0 : int(0.05 * 1920)]
    ladj = lum_a[int(0.26 * 1080) : int(0.75 * 1080), int(0.06 * 1920) : int(0.15 * 1920)]
    log(f"  TR delta={tr.mean()-adj.mean():.2f}  Left delta={le.mean()-ladj.mean():.2f}")


def ensure_ai_base() -> tuple[Path, Path]:
    """Return (base8k, ai32). Build from v5-4x if needed."""
    base8k = OUT / "v5-base-7680x4320.png"
    ai32 = OUT / "v5-ai-30720x17280.png"
    src4 = OUT / "v5-4x-anime.png"
    if not base8k.exists():
        if not src4.exists():
            raise SystemExit(f"missing {src4} — wait for realesrgan 4x")
        log("building 8K base from 4x…")
        im = pyvips.Image.new_from_file(str(src4), access="sequential")
        # 5120x2880 → 7680x4320
        im = im.resize(7680 / im.width, vscale=4320 / im.height, kernel="lanczos3")
        im.pngsave(str(base8k), compression=4)
        log(f"8K base {base8k.stat().st_size/1e6:.1f} MB")
    return base8k, ai32


def main() -> None:
    resume = "--resume" in sys.argv
    base8k, ai32 = ensure_ai_base()
    if not ai32.exists():
        raise SystemExit(
            f"missing {ai32} — run realesrgan 4x on 8K base first:\n"
            f"  realesrgan-ncnn-vulkan -i {base8k} -o {ai32} -n realesrgan-x4plus-anime -s 4 -g 1"
        )

    stars = OUT / "v5-layer-stars-32k.tif"
    nebula = OUT / "v5-layer-nebula-32k.tif"
    hexpath = OUT / "v5-layer-hex-32k.tif"
    mask_path = OUT / "v5-protect-mask-32k.tif"
    master_png = OUT / "laden-os-art-v5-deep-30720x17280.png"

    if not resume:
        for p in (nebula, hexpath, mask_path, master_png):
            if p.exists():
                p.unlink()
                log(f"removed {p.name}")

    if not stars.exists():
        # reuse v4 stars if present to save time
        v4s = OUT / "v4-layer-stars-32k.tif"
        if v4s.exists():
            shutil.copy2(v4s, stars)
            log("reused v4 starfield as v5 stars")
        else:
            stars = gen_starfield_tiles()
    if not nebula.exists():
        nebula = gen_nebula_layer()
    if not hexpath.exists():
        hexpath = gen_hex_circuit_layer()
    if not mask_path.exists():
        mask = make_protect_mask_from_base(base8k)
    else:
        mask = mask_path
        log(f"reusing mask {mask.name}")

    if not master_png.exists():
        blend_all(ai32, stars, nebula, hexpath, mask, master_png)
    else:
        log(f"reusing master {master_png.name}")

    downs = downscale_set(master_png, "laden-os-art-v5")
    phones = phone_crops(master_png, "laden-os-art-v5")
    zoom_crops(master_png)
    seam_qc(DOCS / "laden-os-art-v5-preview-1920x1080.jpg")
    zip_path = build_release_pack(master_png, downs, phones)
    log(f"ALL DONE — release zip {zip_path}")


if __name__ == "__main__":
    main()
