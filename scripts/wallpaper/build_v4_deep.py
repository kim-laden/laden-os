#!/usr/bin/env python3
"""Laden OS v4 32K deep-zoom master: AI base + procedural detail (seam-free).

Fixes vs first build:
- Protect mask uses soft elliptical / gaussian blobs + heavy blur (no hard rectangles).
- Nebula is generated as one continuous low-res field (no per-strip min/max seams).
- Blend still strip-based for RAM; layers themselves have no tile gain mismatch.
"""
from __future__ import annotations

import math
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
import pyvips

OUT = Path("/home/laden/Projects/LadenOS/build/wall-tmp/upscale")
DOCS = Path("/home/laden/Projects/LadenOS/docs/wallpaper")
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
    out = OUT / "v4-layer-stars-32k.tif"
    sdir = OUT / "strips-stars"
    if sdir.exists():
        shutil.rmtree(sdir)
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
    """One continuous low-res nebula field → 32K. No strip seams / gain mismatch."""
    out = OUT / "v4-layer-nebula-32k.tif"
    log(f"generating continuous nebula → {out}")
    sw, sh = 1920, 1080
    n = np.zeros((sh, sw), dtype=np.float32)
    for oi, (sc, amp) in enumerate([(64, 0.42), (32, 0.28), (16, 0.16), (8, 0.09), (4, 0.05)]):
        n += amp * _value_noise(sw, sh, sc, seed=20261109 + oi * 17)
    # Fixed global scale (NOT per-strip min/max)
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
    im = pyvips.Image.new_from_memory(rgb_u8.tobytes(), sw, sh, 3, "uchar")
    # Soft blur at low-res so upscale stays silky
    im = im.gaussblur(1.2)
    full = im.resize(W / sw, vscale=H / sh, kernel="linear")
    if full.width != W or full.height != H:
        full = full.embed(0, 0, W, H, extend="black").crop(0, 0, W, H)
    full.tiffsave(str(out), tile=True, compression="lzw", tile_width=512, tile_height=512, bigtiff=True)
    log(f"nebula done {out.stat().st_size/1e6:.1f} MB (continuous {sw}x{sh}→{W}x{H})")
    return out


def gen_hex_circuit_layer() -> Path:
    out = OUT / "v4-layer-hex-32k.tif"
    rw, rh = W // 2, H // 2
    log(f"generating hex/circuit → {out}")
    sdir = OUT / "strips-hex"
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

    FONT = {
        "0": ["111", "101", "101", "101", "111"],
        "1": ["010", "110", "010", "010", "111"],
        "a": ["010", "101", "111", "101", "101"],
        "d": ["110", "101", "101", "101", "110"],
        "e": ["111", "100", "111", "100", "111"],
        "l": ["100", "100", "100", "100", "111"],
        "n": ["101", "111", "111", "101", "101"],
        ".": ["000", "000", "000", "000", "010"],
        "'": ["010", "010", "000", "000", "000"],
        "s": ["011", "100", "010", "001", "110"],
        "t": ["111", "010", "010", "010", "010"],
        "o": ["111", "101", "101", "101", "111"],
        "i": ["010", "000", "010", "010", "010"],
        " ": ["000", "000", "000", "000", "000"],
        "L": ["100", "100", "100", "100", "111"],
    }
    eggs = [
        ("laden.no", int(rw * 0.12), int(rh * 0.18)),
        ("Let's do it", int(rw * 0.78), int(rh * 0.22)),
        ("0101", int(rw * 0.20), int(rh * 0.80)),
        ("L", int(rw * 0.88), int(rh * 0.72)),
        ("laden", int(rw * 0.55), int(rh * 0.88)),
    ]
    egg_pixels = []
    for text, x0, y0 in eggs:
        x = x0
        for ch in text:
            glyph = FONT.get(ch, FONT.get(ch.lower(), FONT[" "]))
            for row, bits in enumerate(glyph):
                for col, bit in enumerate(bits):
                    if bit == "1":
                        egg_pixels.append((x + col, y0 + row, EMERALD[0], EMERALD[1], EMERALD[2], 0.9))
            x += 4
    const = [(int(rw * 0.62), int(rh * 0.08)), (int(rw * 0.63), int(rh * 0.09)),
             (int(rw * 0.645), int(rh * 0.085)), (int(rw * 0.66), int(rh * 0.10)),
             (int(rw * 0.67), int(rh * 0.07))]
    for i, (x, y) in enumerate(const):
        egg_pixels.append((x, y, EMERALD[0], EMERALD[1], EMERALD[2], 0.9))
        if i:
            add_line(const[i - 1][0], const[i - 1][1], x, y, TEAL, 0.35)

    log(f"  segs={len(segs)} nodes={len(nodes)} eggs={len(egg_pixels)}")

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
            n = int(L / step)
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

    half = OUT / "v4-layer-hex-half.tif"
    vips_join_vertical_simple(paths, half)
    shutil.rmtree(sdir, ignore_errors=True)
    log("  nearest-upscale hex to 32K…")
    full = pyvips.Image.new_from_file(str(half), access="sequential").resize(2.0, kernel="nearest")
    if full.width != W or full.height != H:
        full = full.embed(0, 0, W, H, extend="black").crop(0, 0, W, H)
    full.tiffsave(str(out), tile=True, compression="lzw", tile_width=512, tile_height=512, bigtiff=True)
    half.unlink(missing_ok=True)
    log(f"hex done {out.stat().st_size/1e6:.1f} MB")
    (OUT / "v4-easter-eggs.txt").write_text(
        "\n".join(f"{t}:{x*2},{y*2}" for t, x, y in eggs) + "\n"
    )
    return out


def _soft_blob(reg: np.ndarray, cy: float, cx: float, ry: float, rx: float, strength: float = 1.0) -> None:
    """Add a soft elliptical gaussian blob (values in 0..strength) into reg in-place."""
    rh, rw = reg.shape
    yy = np.arange(rh, dtype=np.float32)[:, None]
    xx = np.arange(rw, dtype=np.float32)[None, :]
    d = ((yy - cy) / max(ry, 1e-3)) ** 2 + ((xx - cx) / max(rx, 1e-3)) ** 2
    blob = np.exp(-0.5 * d) * strength
    np.maximum(reg, blob, out=reg)


def make_protect_mask_from_base(base8k_path: Path) -> Path:
    """Content protect + soft geometric blobs. Heavy blur — no hard rectangles."""
    out = OUT / "v4-protect-mask-32k.tif"
    log("building soft protect mask…")
    im = pyvips.Image.new_from_file(str(base8k_path), access="sequential")
    lum = im.bandmean()
    r, g, b = im[0], im[1], im[2]
    greenish = (g > r * 1.05) & (g > b * 0.9) & (g > 40)
    bright = lum > 55
    # Softer content protect (larger blur so edges don't brick)
    protect = (greenish | bright).ifthenelse(255, 0).gaussblur(10).cast("uchar")
    protect = (protect > 12).ifthenelse(protect, 0)

    w8, h8 = im.width, im.height
    rw, rh = 960, 540
    reg = np.zeros((rh, rw), dtype=np.float32)

    # Soft blobs instead of hard rectangles (positions as fractions of frame)
    # LADEN letters
    _soft_blob(reg, 0.45 * rh, 0.50 * rw, 0.20 * rh, 0.36 * rw, 1.0)
    # OS / Let's do it
    _soft_blob(reg, 0.66 * rh, 0.50 * rw, 0.10 * rh, 0.22 * rw, 0.95)
    # Planet bottom-left
    _soft_blob(reg, 0.90 * rh, 0.12 * rw, 0.22 * rh, 0.20 * rw, 1.0)
    # Rocket (soft around ship — NOT a hard TR corner box)
    _soft_blob(reg, 0.18 * rh, 0.90 * rw, 0.16 * rh, 0.10 * rw, 0.95)
    _soft_blob(reg, 0.28 * rh, 0.90 * rw, 0.10 * rh, 0.06 * rw, 0.7)  # plume
    # Left icons (fingerprint / shield / wave)
    for fy in (0.32, 0.48, 0.62):
        _soft_blob(reg, fy * rh, 0.07 * rw, 0.07 * rh, 0.05 * rw, 0.85)
    # Right icons
    for fy, fx in ((0.30, 0.93), (0.48, 0.93), (0.78, 0.90)):
        _soft_blob(reg, fy * rh, fx * rw, 0.07 * rh, 0.05 * rw, 0.85)

    # Extra heavy feather at working res (~4% of frame)
    reg_img = pyvips.Image.new_from_memory(reg.tobytes(), rw, rh, 1, "float")
    reg_img = reg_img.gaussblur(28)
    reg_img = (reg_img > 1.0).ifthenelse(1.0, reg_img)
    reg_img = (reg_img < 0.0).ifthenelse(0.0, reg_img)
    reg_img = reg_img.resize(w8 / rw, vscale=h8 / rh, kernel="linear")
    reg_u8 = (reg_img * 255).cast("uchar")

    combined = (protect > reg_u8).ifthenelse(protect, reg_u8).gaussblur(6)
    combined32 = combined.resize(W / w8, vscale=H / h8, kernel="linear").cast("uchar")
    # Final soft edge at 32K (kill any residual hard steps)
    combined32 = combined32.gaussblur(18).cast("uchar")
    combined32.tiffsave(str(out), tile=True, compression="lzw", tile_width=512, tile_height=512, bigtiff=True)
    log(f"soft mask {out.stat().st_size/1e6:.1f} MB")
    del combined32, combined, protect, reg_img, im
    # Preview of mask for QC (reopen — sequential graph already consumed)
    prev = pyvips.Image.new_from_file(str(out), access="sequential").resize(
        1920 / W, vscale=1080 / H, kernel="linear"
    )
    prev.jpegsave(str(DOCS / "protect-mask-preview-soft.jpg"), Q=85)
    return out


def blend_all(ai_path: Path, stars: Path, nebula: Path, hexpath: Path, mask: Path, out_png: Path) -> None:
    log("blending in strips…")
    sdir = OUT / "strips-blend"
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
    mid = OUT / "v4-deep-master-mid.tif"
    vips_join_vertical_simple(paths, mid)
    shutil.rmtree(sdir, ignore_errors=True)
    log("writing final 32K PNG…")
    master = pyvips.Image.new_from_file(str(mid), access="sequential")
    master.pngsave(str(out_png), compression=4)
    sz = out_png.stat().st_size
    log(f"master PNG {sz/1e6:.1f} MB")
    mid.unlink(missing_ok=True)


def downscale_set(master_path: Path, stem: str) -> None:
    for w, h in [(7680, 4320), (3840, 2160), (2560, 1440), (1920, 1080)]:
        log(f"downscale {w}x{h}")
        master = pyvips.Image.new_from_file(str(master_path), access="sequential")
        im = master.resize(w / master.width, vscale=h / master.height, kernel="lanczos3")
        im.pngsave(str(OUT / f"{stem}-{w}x{h}.png"), compression=9)
    log("downscale 3440x1440")
    master = pyvips.Image.new_from_file(str(master_path), access="sequential")
    im = master.resize(3440 / master.width, kernel="lanczos3")
    top = max(0, (im.height - 1440) // 2)
    im = im.crop(0, top, 3440, 1440)
    im.pngsave(str(OUT / f"{stem}-3440x1440.png"), compression=9)


def zoom_crops(master_path: Path, docs: Path) -> None:
    docs.mkdir(parents=True, exist_ok=True)
    im = pyvips.Image.new_from_file(str(master_path), access="random")
    eggs = {}
    eggfile = OUT / "v4-easter-eggs.txt"
    if eggfile.exists():
        for line in eggfile.read_text().splitlines():
            k, v = line.split(":")
            x, y = map(int, v.split(","))
            eggs[k] = (x, y)
    crops = {
        "v4-zoom-logo-edge.png": (int(W * 0.40), int(H * 0.36), 1200, 800),
        "v4-zoom-grid-tunnel.png": (int(W * 0.42), int(H * 0.55), 1400, 900),
        "v4-zoom-starfield.png": (int(W * 0.05), int(H * 0.05), 1000, 1000),
        # Former problem areas
        "v4-zoom-fix-rocket-tr.png": (int(W * 0.74), int(H * 0.02), 1600, 1200),
        "v4-zoom-fix-left-edge.png": (int(W * 0.00), int(H * 0.28), 900, 1400),
    }
    if "laden.no" in eggs:
        x, y = eggs["laden.no"]
        crops["v4-zoom-easter-ladenno.png"] = (x - 80, y - 60, 500, 300)
    for name, (x, y, w, h) in crops.items():
        x = max(0, min(x, W - w))
        y = max(0, min(y, H - h))
        im.crop(x, y, w, h).pngsave(str(docs / name), compression=6)
        log(f"crop {name}")
    im.resize(1920 / W, kernel="lanczos3").jpegsave(str(docs / "laden-os-v4-preview-1920x1080.jpg"), Q=90)
    # Also copy 1920 png into docs for convenience
    shutil.copy(OUT / "laden-os-lets-do-it-v4-1920x1080.png", docs / "laden-os-v4-1920x1080.png")


def seam_qc(preview_jpg: Path) -> None:
    """Local-contrast / edge map + region luminance deltas for former hard boxes."""
    log("seam QC…")
    im = pyvips.Image.new_from_file(str(preview_jpg))
    lum = im.bandmean().cast("float")
    gx = lum.conv(pyvips.Image.new_from_array([[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]], scale=1))
    gy = lum.conv(pyvips.Image.new_from_array([[-1, -2, -1], [0, 0, 0], [1, 2, 1]], scale=1))
    mag = ((gx * gx + gy * gy) ** 0.5)
    mag_u8 = (mag * 3).cast("uchar")
    mag_u8.jpegsave(str(DOCS / "v4-seam-edge-map.jpg"), Q=90)

    arr = np.frombuffer(im.write_to_memory(), dtype=np.uint8).reshape(im.height, im.width, im.bands)
    lum_a = arr.mean(axis=2)
    tr = lum_a[0:int(0.31 * 1080), int(0.77 * 1920) :]
    adj = lum_a[0:int(0.31 * 1080), int(0.60 * 1920) : int(0.75 * 1920)]
    le = lum_a[int(0.26 * 1080) : int(0.75 * 1080), 0 : int(0.05 * 1920)]
    ladj = lum_a[int(0.26 * 1080) : int(0.75 * 1080), int(0.06 * 1920) : int(0.15 * 1920)]
    # Vertical gradient energy near former rocket edge (x≈0.78) — hard seams spike this
    x78 = int(0.78 * 1920)
    seam_band = np.abs(np.diff(lum_a[0:int(0.35 * 1080), x78 - 3 : x78 + 3], axis=1)).mean()
    log(f"  TR box mean={tr.mean():.2f} adj={adj.mean():.2f} delta={tr.mean()-adj.mean():.2f}")
    log(f"  Left box mean={le.mean():.2f} adj={ladj.mean():.2f} delta={le.mean()-ladj.mean():.2f}")
    log(f"  rocket-edge |dL| mean={seam_band:.3f} (lower is better; hard seam was ~high)")
    # Flag if still looking like a hard box (abrupt >8 point step)
    if abs(tr.mean() - adj.mean()) > 8 or abs(le.mean() - ladj.mean()) > 8:
        log("  WARNING: region delta still large — inspect preview")
    else:
        log("  region deltas OK (<8)")


def main() -> None:
    force = "--force" in sys.argv
    base8k = OUT / "v4-base-7680x4320.png"
    ai32 = OUT / "v4-ai-30720x17280.png"
    if not ai32.exists():
        raise SystemExit(f"missing {ai32}")
    stars = OUT / "v4-layer-stars-32k.tif"
    nebula = OUT / "v4-layer-nebula-32k.tif"
    hexpath = OUT / "v4-layer-hex-32k.tif"

    mask_path = OUT / "v4-protect-mask-32k.tif"
    master_png = OUT / "laden-os-v4-deep-30720x17280.png"
    resume = "--resume" in sys.argv

    if force and not resume:
        if nebula.exists():
            nebula.unlink()
            log("removed old nebula")
        if mask_path.exists():
            mask_path.unlink()
            log("removed old protect mask")
        if master_png.exists():
            master_png.unlink()
            log("removed old master PNG")

    if not stars.exists():
        stars = gen_starfield_tiles(tile=1024)
    if not nebula.exists():
        nebula = gen_nebula_layer()
    else:
        log(f"reusing nebula {nebula.name}")
    if not hexpath.exists():
        hexpath = gen_hex_circuit_layer()
    if not mask_path.exists():
        mask = make_protect_mask_from_base(base8k)
    else:
        mask = mask_path
        log(f"reusing mask {mask.name}")
        soft_prev = DOCS / "protect-mask-preview-soft.jpg"
        if not soft_prev.exists():
            prev = pyvips.Image.new_from_file(str(mask), access="sequential").resize(
                1920 / W, vscale=1080 / H, kernel="linear"
            )
            prev.jpegsave(str(soft_prev), Q=85)
    blend_all(ai32, stars, nebula, hexpath, mask, master_png)
    downscale_set(master_png, "laden-os-lets-do-it-v4")
    zoom_crops(master_png, DOCS)
    seam_qc(DOCS / "laden-os-v4-preview-1920x1080.jpg")
    log("ALL DONE")


if __name__ == "__main__":
    main()
