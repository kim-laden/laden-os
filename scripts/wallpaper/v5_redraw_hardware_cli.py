#!/usr/bin/env python3
"""Redraw Laden OS Art v5 hardware + CLI as crisp full-32K vector overlays.

Drawn AFTER AI upscale (cairo), then composited onto the 32K master with soft glow.
Devices ~150–400px tall; strokes 1.5–3px; subtle overall opacity.
"""
from __future__ import annotations

import math
import shutil
from pathlib import Path

import cairo
import numpy as np
import pyvips

_REPO = Path(__file__).resolve().parents[2]
OUT = _REPO / "build/wall-tmp/upscale"
DOCS = _REPO / "docs/wallpaper"
RELEASE = _REPO / "build/art-release/v5"
MASTER = OUT / "laden-os-art-v5-deep-30720x17280.png"
W, H = 30720, 17280

# Emerald
ER, EG, EB = 0x2E / 255.0, 0xE0 / 255.0, 0x7A / 255.0
TR, TG, TB = 0x1A / 255.0, 0xC8 / 255.0, 0xB4 / 255.0


def log(msg: str) -> None:
    print(msg, flush=True)


def glow_stroke(ctx: cairo.Context, path_fn, base_width: float, rgba, glow_passes: int = 6):
    """Soft glow: wide faint strokes then crisp core. base_width is visual ~px."""
    r, g, b, a = rgba
    base_width = max(2.0, base_width * 1.35)  # keep 1–3px core readable, prefer ~2.5–3.5
    for i in range(glow_passes, 0, -1):
        w = base_width * (1.0 + i * 1.5)
        aa = a * (0.07 * (glow_passes - i + 1) / glow_passes)
        ctx.set_line_width(w)
        ctx.set_source_rgba(r, g, b, aa)
        path_fn(ctx)
        ctx.stroke()
    ctx.set_line_width(base_width)
    ctx.set_source_rgba(r, g, b, min(1.0, a))
    path_fn(ctx)
    ctx.stroke()


def poly(ctx, pts, close=False):
    ctx.new_path()
    ctx.move_to(*pts[0])
    for p in pts[1:]:
        ctx.line_to(*p)
    if close:
        ctx.close_path()


# Device drawers: local coords with height ~1.0, origin at center. Return height scale hint.
def draw_flipper(ctx, s: float, rgba):
    # Rounded body ~ phone remote, screen, D-pad circle, buttons — no dolphin logo
    def body(c):
        # rounded rect body
        x, y, w, h, r = -0.38 * s, -0.48 * s, 0.76 * s, 0.96 * s, 0.10 * s
        c.new_path()
        c.arc(x + r, y + r, r, math.pi, 1.5 * math.pi)
        c.arc(x + w - r, y + r, r, 1.5 * math.pi, 2 * math.pi)
        c.arc(x + w - r, y + h - r, r, 0, 0.5 * math.pi)
        c.arc(x + r, y + h - r, r, 0.5 * math.pi, math.pi)
        c.close_path()

    def screen(c):
        poly(c, [(-0.28*s, -0.38*s), (0.28*s, -0.38*s), (0.28*s, -0.02*s), (-0.28*s, -0.02*s)], True)

    def dpad(c):
        c.new_path()
        c.arc(-0.12*s, 0.22*s, 0.10*s, 0, 2*math.pi)

    def btn1(c):
        c.new_path(); c.arc(0.16*s, 0.16*s, 0.055*s, 0, 2*math.pi)

    def btn2(c):
        c.new_path(); c.arc(0.16*s, 0.32*s, 0.055*s, 0, 2*math.pi)

    def antenna_stem(c):
        poly(c, [(0.0, -0.48*s), (0.0, -0.58*s)])

    def antenna_tip(c):
        c.new_path(); c.arc(0.0, -0.60*s, 0.028*s, 0, 2*math.pi)

    for fn, w in ((body, 2.6), (screen, 2.0), (dpad, 2.2), (btn1, 1.8), (btn2, 1.8), (antenna_stem, 2.0), (antenna_tip, 1.8)):
        glow_stroke(ctx, fn, w, rgba)


def draw_pineapple(ctx, s: float, rgba):
    # Flat box + 3 vertical antennas with small tips
    def body(c):
        poly(c, [(-0.42*s, 0.05*s), (0.42*s, 0.05*s), (0.42*s, 0.42*s), (-0.42*s, 0.42*s)], True)

    def ant1(c):
        poly(c, [(-0.28*s, 0.05*s), (-0.28*s, -0.48*s)])
    def ant1t(c):
        c.new_path(); c.arc(-0.28*s, -0.52*s, 0.038*s, 0, 2*math.pi)
    def ant2(c):
        poly(c, [(0.0, 0.05*s), (0.0, -0.55*s)])
    def ant2t(c):
        c.new_path(); c.arc(0.0, -0.59*s, 0.038*s, 0, 2*math.pi)
    def ant3(c):
        poly(c, [(0.28*s, 0.05*s), (0.28*s, -0.48*s)])
    def ant3t(c):
        c.new_path(); c.arc(0.28*s, -0.52*s, 0.038*s, 0, 2*math.pi)
    def port1(c):
        poly(c, [(-0.30*s, 0.18*s), (-0.10*s, 0.18*s), (-0.10*s, 0.30*s), (-0.30*s, 0.30*s)], True)
    def port2(c):
        poly(c, [(0.10*s, 0.18*s), (0.30*s, 0.18*s), (0.30*s, 0.30*s), (0.10*s, 0.30*s)], True)

    for fn, w in ((body, 2.8), (ant1, 2.4), (ant1t, 2.0), (ant2, 2.4), (ant2t, 2.0), (ant3, 2.4), (ant3t, 2.0), (port1, 1.8), (port2, 1.8)):
        glow_stroke(ctx, fn, w, rgba)


def draw_ducky(ctx, s: float, rgba):
    def body(c):
        poly(c, [(-0.48*s, -0.18*s), (0.18*s, -0.18*s), (0.18*s, 0.18*s), (-0.48*s, 0.18*s)], True)
    def plug_body(c):
        poly(c, [(0.18*s, -0.12*s), (0.48*s, -0.12*s), (0.48*s, 0.12*s), (0.18*s, 0.12*s)], True)
    def plug_pin1(c):
        poly(c, [(0.48*s, -0.06*s), (0.55*s, -0.06*s)])
    def plug_pin2(c):
        poly(c, [(0.48*s, 0.06*s), (0.55*s, 0.06*s)])
    def led(c):
        c.new_path(); c.arc(-0.30*s, 0.0, 0.05*s, 0, 2*math.pi)
    for fn, w in ((body, 2.8), (plug_body, 2.4), (plug_pin1, 2.0), (plug_pin2, 2.0), (led, 2.0)):
        glow_stroke(ctx, fn, w, rgba)


def draw_hackrf(ctx, s: float, rgba):
    def board(c):
        poly(c, [(-0.45*s, -0.28*s), (0.45*s, -0.28*s), (0.45*s, 0.28*s), (-0.45*s, 0.28*s)], True)
    def sma_body(c):
        poly(c, [(-0.08*s, -0.28*s), (-0.08*s, -0.42*s), (0.08*s, -0.42*s), (0.08*s, -0.28*s)], True)
    def sma_tip(c):
        c.new_path(); c.arc(0.0, -0.50*s, 0.055*s, 0, 2*math.pi)
    def chip(c):
        poly(c, [(-0.18*s, -0.10*s), (0.18*s, -0.10*s), (0.18*s, 0.12*s), (-0.18*s, 0.12*s)], True)
    def usb(c):
        poly(c, [(-0.45*s, -0.08*s), (-0.58*s, -0.08*s), (-0.58*s, 0.08*s), (-0.45*s, 0.08*s)], True)
    for fn, w in ((board, 2.8), (sma_body, 2.3), (sma_tip, 2.2), (chip, 2.0), (usb, 2.0)):
        glow_stroke(ctx, fn, w, rgba)


def draw_proxmark(ctx, s: float, rgba):
    def board(c):
        poly(c, [(-0.40*s, -0.18*s), (0.40*s, -0.18*s), (0.40*s, 0.22*s), (-0.40*s, 0.22*s)], True)
    def coil_outer(c):
        c.new_path(); c.arc(0.0, -0.02*s, 0.26*s, 0, 2*math.pi)
    def coil_inner(c):
        c.new_path(); c.arc(0.0, -0.02*s, 0.15*s, 0, 2*math.pi)
    def usb(c):
        poly(c, [(0.40*s, -0.06*s), (0.55*s, -0.06*s), (0.55*s, 0.06*s), (0.40*s, 0.06*s)], True)
    for fn, w in ((board, 2.6), (coil_outer, 2.5), (coil_inner, 2.2), (usb, 2.0)):
        glow_stroke(ctx, fn, w, rgba)


def draw_lan_turtle(ctx, s: float, rgba):
    def body(c):
        poly(c, [(-0.35*s, -0.22*s), (0.12*s, -0.22*s), (0.12*s, 0.22*s), (-0.35*s, 0.22*s)], True)
    def rj45(c):
        poly(c, [(0.12*s, -0.14*s), (0.42*s, -0.14*s), (0.42*s, 0.14*s), (0.12*s, 0.14*s)], True)
    def rj_slot1(c):
        poly(c, [(0.18*s, -0.08*s), (0.36*s, -0.08*s)])
    def rj_slot2(c):
        poly(c, [(0.18*s, 0.0), (0.36*s, 0.0)])
    def rj_slot3(c):
        poly(c, [(0.18*s, 0.08*s), (0.36*s, 0.08*s)])
    def usb(c):
        poly(c, [(-0.35*s, -0.10*s), (-0.52*s, -0.10*s), (-0.52*s, 0.10*s), (-0.35*s, 0.10*s)], True)
    for fn, w in ((body, 2.6), (rj45, 2.2), (rj_slot1, 1.8), (rj_slot2, 1.8), (rj_slot3, 1.8), (usb, 2.0)):
        glow_stroke(ctx, fn, w, rgba)


def draw_bash_bunny(ctx, s: float, rgba):
    def body(c):
        poly(c, [(-0.42*s, -0.20*s), (0.20*s, -0.20*s), (0.20*s, 0.20*s), (-0.42*s, 0.20*s)], True)

    def plug(c):
        poly(c, [(0.20*s, -0.12*s), (0.48*s, -0.12*s), (0.48*s, 0.12*s), (0.20*s, 0.12*s)], True)

    def sw1(c):
        poly(c, [(-0.30*s, -0.08*s), (-0.08*s, -0.08*s)])
    def sw2(c):
        poly(c, [(-0.30*s, 0.0), (-0.08*s, 0.0)])
    def sw3(c):
        poly(c, [(-0.30*s, 0.08*s), (-0.08*s, 0.08*s)])
    for fn, w in ((body, 2.6), (plug, 2.2), (sw1, 1.9), (sw2, 1.9), (sw3, 1.9)):
        glow_stroke(ctx, fn, w, rgba)


def draw_omg_cable(ctx, s: float, rgba):
    def cable(c):
        c.new_path()
        c.move_to(-0.48*s, 0.0)
        c.curve_to(-0.20*s, -0.18*s, 0.20*s, 0.18*s, 0.48*s, 0.0)

    def end_a(c):
        poly(c, [(-0.55*s, -0.10*s), (-0.42*s, -0.10*s), (-0.42*s, 0.10*s), (-0.55*s, 0.10*s)], True)

    def end_b(c):
        poly(c, [(0.42*s, -0.10*s), (0.55*s, -0.10*s), (0.55*s, 0.10*s), (0.42*s, 0.10*s)], True)

    for fn, w in ((cable, 2.5), (end_a, 2.0), (end_b, 2.0)):
        glow_stroke(ctx, fn, w, rgba)


def draw_esp32_nugget(ctx, s: float, rgba):
    def board(c):
        poly(c, [(-0.32*s, -0.28*s), (0.32*s, -0.28*s), (0.32*s, 0.28*s), (-0.32*s, 0.28*s)], True)
    def ant_stem(c):
        poly(c, [(0.0, -0.28*s), (0.0, -0.48*s)])
    def ant_tip(c):
        c.new_path(); c.arc(0.0, -0.52*s, 0.035*s, 0, 2*math.pi)
    def chip(c):
        poly(c, [(-0.14*s, -0.10*s), (0.14*s, -0.10*s), (0.14*s, 0.10*s), (-0.14*s, 0.10*s)], True)
    def pin1(c):
        poly(c, [(-0.20*s, 0.28*s), (-0.20*s, 0.42*s)])
    def pin2(c):
        poly(c, [(0.0, 0.28*s), (0.0, 0.42*s)])
    def pin3(c):
        poly(c, [(0.20*s, 0.28*s), (0.20*s, 0.42*s)])
    for fn, w in ((board, 2.6), (ant_stem, 2.2), (ant_tip, 2.0), (chip, 1.9), (pin1, 1.8), (pin2, 1.8), (pin3, 1.8)):
        glow_stroke(ctx, fn, w, rgba)


DEVICES = [
    # name, fx, fy, height_px, drawer, alpha — calm dark pockets; 150–400px tall
    ("flipper-zero",        0.16, 0.58, 360, draw_flipper,      0.92),
    ("wifi-pineapple-mk7",  0.46, 0.78, 340, draw_pineapple,    0.90),
    ("usb-rubber-ducky",    0.07, 0.52, 260, draw_ducky,        0.92),
    ("hackrf-one",          0.86, 0.38, 340, draw_hackrf,       0.90),
    ("proxmark3",           0.30, 0.88, 300, draw_proxmark,     0.88),
    ("lan-turtle",          0.90, 0.72, 220, draw_lan_turtle,   0.88),
    ("bash-bunny",          0.12, 0.40, 250, draw_bash_bunny,   0.90),
    ("omg-cable",           0.62, 0.90, 280, draw_omg_cable,    0.82),
    ("esp32-nugget",        0.78, 0.48, 230, draw_esp32_nugget, 0.88),
    ("wifi-pineapple-mk7-deep", 0.52, 0.93, 160, draw_pineapple, 0.55),
]

CLI = [
    # text, fx, fy, pixel_height, alpha
    ("nmap -sV -A", 0.22, 0.66, 22, 0.82),
    ("msfconsole", 0.58, 0.72, 16, 0.70),
    ("use exploit/multi/handler", 0.38, 0.86, 14, 0.65),
    ("aircrack-ng", 0.70, 0.70, 16, 0.70),
    ("hashcat -m 22000", 0.30, 0.90, 14, 0.60),
    ("john --wordlist", 0.80, 0.58, 15, 0.70),
    ("sqlmap -u", 0.18, 0.82, 15, 0.68),
    ("hydra -l", 0.90, 0.70, 14, 0.65),
    ("nc -lvnp 4444", 0.50, 0.90, 14, 0.55),
    ("sudo pacman -Syu", 0.24, 0.44, 20, 0.80),
    ("whoami", 0.66, 0.48, 20, 0.80),
    ("uname -a", 0.08, 0.42, 16, 0.72),
    ("ssh root@", 0.92, 0.50, 15, 0.68),
    ("tcpdump -i", 0.40, 0.62, 15, 0.70),
    ("gobuster dir", 0.76, 0.86, 14, 0.60),
    ("0x41414141", 0.55, 0.56, 20, 0.80),
    ("It's not a bug", 0.34, 0.54, 15, 0.68),
    ("Hack the planet", 0.48, 0.95, 13, 0.50),
]


def render_device_png(name: str, height: float, drawer, alpha: float) -> Path:
    # Drawers use local coords in roughly ±0.55*s, so s≈height makes the glyph ~height px tall.
    s = float(height)
    pad = int(height * 0.45)
    size = int(height + 2 * pad)
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, size, size)
    ctx = cairo.Context(surf)
    ctx.set_line_cap(cairo.LINE_CAP_ROUND)
    ctx.set_line_join(cairo.LINE_JOIN_ROUND)
    ctx.translate(size / 2, size / 2)
    drawer(ctx, s, (ER, EG, EB, alpha))
    path = OUT / f"_egg_{name}.png"
    surf.write_to_png(str(path))
    return path


def render_cli_png(text: str, px_h: float, alpha: float) -> Path:
    # monospace-ish via cairo toy font
    pad_x, pad_y = 20, 16
    # estimate width
    surf0 = cairo.ImageSurface(cairo.FORMAT_ARGB32, 8, 8)
    ctx0 = cairo.Context(surf0)
    ctx0.select_font_face("monospace", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
    ctx0.set_font_size(px_h)
    xb, yb, tw, th, _, _ = ctx0.text_extents(text)
    w = int(tw + pad_x * 2 + 8)
    h = int(px_h + pad_y * 2 + 8)
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, max(w, 8), max(h, 8))
    ctx = cairo.Context(surf)
    ctx.select_font_face("monospace", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
    ctx.set_font_size(px_h)
    x0 = pad_x - xb
    y0 = pad_y + px_h * 0.8
    # glow
    for i in range(4, 0, -1):
        ctx.set_source_rgba(TR, TG, TB, alpha * 0.06 * i)
        ctx.move_to(x0, y0)
        ctx.set_line_width(1.0 + i * 1.2)
        ctx.text_path(text)
        ctx.stroke()
    ctx.set_source_rgba(TR, TG, TB, alpha)
    ctx.move_to(x0, y0)
    ctx.show_text(text)
    safe = "".join(c if c.isalnum() else "_" for c in text)[:40]
    path = OUT / f"_cli_{safe}.png"
    surf.write_to_png(str(path))
    return path, w, h


def _screen_region(base: pyvips.Image, rgb: pyvips.Image, a: pyvips.Image, x: int, y: int) -> pyvips.Image:
    """Screen-blend overlay into base only in the overlay bbox (memory-safe)."""
    ow, oh = rgb.width, rgb.height
    region = base.crop(x, y, ow, oh)
    bf = region / 255.0
    of = rgb / 255.0
    aa = a if a.bands == 1 else a.extract_band(0)
    screened = 1.0 - (1.0 - bf) * (1.0 - of * aa)
    blended = (screened * 255.0).cast("uchar")
    return base.insert(blended, x, y)


def composite_overlays(master_path: Path, out_path: Path) -> list[tuple]:
    """Composite device + CLI PNGs onto master; return placement metadata (32K coords)."""
    log("loading master for composite…")
    # Start from a disk copy we mutate via successive insert writes to keep graph shallow
    work = OUT / "_v5_composite_work.tif"
    base0 = pyvips.Image.new_from_file(str(master_path), access="sequential")
    if base0.bands > 3:
        base0 = base0.extract_band(0, n=3)
    base0.tiffsave(str(work), tile=True, compression="lzw", tile_width=512, tile_height=512, bigtiff=True)
    del base0

    meta_hw = []
    for name, fx, fy, height, drawer, alpha in DEVICES:
        log(f"  device {name} h={height}px @ ({fx:.2f},{fy:.2f})")
        png = render_device_png(name, height, drawer, alpha)
        overlay = pyvips.Image.new_from_file(str(png))
        if overlay.bands == 4:
            # Cairo ARGB32 often comes in as BGRA in memory; pyvips PNG load is RGBA
            rgb = overlay.extract_band(0, n=3)
            a = overlay.extract_band(3) / 255.0
        else:
            rgb = overlay
            a = (overlay.bandmean() / 255.0)
        ow, oh = overlay.width, overlay.height
        cx, cy = int(W * fx), int(H * fy)
        x = max(0, min(cx - ow // 2, W - ow))
        y = max(0, min(cy - oh // 2, H - oh))
        acc = pyvips.Image.new_from_file(str(work), access="random")
        acc = _screen_region(acc, rgb, a, x, y)
        nxt = OUT / "_v5_composite_next.tif"
        acc.tiffsave(str(nxt), tile=True, compression="lzw", tile_width=512, tile_height=512, bigtiff=True)
        work.unlink(missing_ok=True)
        nxt.rename(work)
        meta_hw.append((name.replace("-deep", ""), x + ow // 2, y + oh // 2, height, x, y, ow, oh))
        png.unlink(missing_ok=True)
        del overlay, rgb, a, acc

    meta_cli = []
    for text, fx, fy, px_h, alpha in CLI:
        log(f"  cli {text!r}")
        png, tw, th = render_cli_png(text, px_h, alpha)
        overlay = pyvips.Image.new_from_file(str(png))
        if overlay.bands == 4:
            rgb = overlay.extract_band(0, n=3)
            a = overlay.extract_band(3) / 255.0
        else:
            rgb = overlay
            a = overlay.bandmean() / 255.0
        ow, oh = overlay.width, overlay.height
        cx, cy = int(W * fx), int(H * fy)
        x = max(0, min(cx - ow // 2, W - ow))
        y = max(0, min(cy - oh // 2, H - oh))
        acc = pyvips.Image.new_from_file(str(work), access="random")
        acc = _screen_region(acc, rgb, a, x, y)
        nxt = OUT / "_v5_composite_next.tif"
        acc.tiffsave(str(nxt), tile=True, compression="lzw", tile_width=512, tile_height=512, bigtiff=True)
        work.unlink(missing_ok=True)
        nxt.rename(work)
        meta_cli.append((text, x, y, ow, oh))
        png.unlink(missing_ok=True)
        del overlay, rgb, a, acc

    log("writing updated 32K master PNG…")
    final = pyvips.Image.new_from_file(str(work), access="sequential")
    tmp = out_path.with_suffix(".tmp.png")
    final.pngsave(str(tmp), compression=4)
    tmp.replace(out_path)
    work.unlink(missing_ok=True)
    log(f"master {out_path.stat().st_size/1e6:.1f} MB")

    (OUT / "v5-hardware-eggs.txt").write_text(
        "\n".join(f"{n}:{cx},{cy}:{h}:{x},{y},{w},{hh}" for n, cx, cy, h, x, y, w, hh in meta_hw) + "\n"
    )
    (OUT / "v5-cli-eggs.txt").write_text(
        "\n".join(f"{t}:{x},{y}:{w}x{h}" for t, x, y, w, h in meta_cli) + "\n"
    )
    return meta_hw, meta_cli


def downscales_and_pack(master: Path):
    stem = "laden-os-art-v5"
    downs = {}
    for w, h in [(7680, 4320), (3840, 2160), (2560, 1440), (1920, 1080)]:
        log(f"downscale {w}x{h}")
        im = pyvips.Image.new_from_file(str(master), access="sequential")
        im = im.resize(w / im.width, vscale=h / im.height, kernel="lanczos3")
        p = OUT / f"{stem}-{w}x{h}.png"
        im.pngsave(str(p), compression=9)
        downs[f"{w}x{h}"] = p
    log("downscale 3440x1440")
    im = pyvips.Image.new_from_file(str(master), access="sequential")
    im = im.resize(3440 / im.width, kernel="lanczos3")
    top = max(0, (im.height - 1440) // 2)
    im = im.crop(0, top, 3440, 1440)
    p = OUT / f"{stem}-3440x1440.png"
    im.pngsave(str(p), compression=9)
    downs["3440x1440"] = p

    phones = {}
    for tw, th in [(1290, 2796), (1440, 3200)]:
        m = pyvips.Image.new_from_file(str(master), access="random")
        scale = max(tw / m.width, th / m.height)
        im = m.resize(scale, kernel="lanczos3")
        left = max(0, int((im.width - tw) * 0.48))
        top = max(0, (im.height - th) // 2)
        im = im.crop(left, top, min(tw, im.width), min(th, im.height))
        if im.width != tw or im.height != th:
            im = im.embed(0, 0, tw, th, extend="black")
        pp = OUT / f"{stem}-{tw}x{th}.png"
        im.pngsave(str(pp), compression=9)
        phones[f"{tw}x{th}"] = pp
        log(f"phone {tw}x{th}")
    return downs, phones


def zoom_crops(master: Path, meta_hw, meta_cli):
    DOCS.mkdir(parents=True, exist_ok=True)
    im = pyvips.Image.new_from_file(str(master), access="random")
    # Pick 4 distinct devices for 100% crops (device bbox + margin)
    want = ["flipper-zero", "wifi-pineapple-mk7", "usb-rubber-ducky", "hackrf-one", "proxmark3"]
    seen = set()
    crops = []
    for n, cx, cy, h, x, y, w, hh in meta_hw:
        if n in want and n not in seen:
            seen.add(n)
            margin = 80
            crops.append((f"v5-zoom-100pct-{n}.png", max(0, x - margin), max(0, y - margin),
                          min(W - max(0, x - margin), w + 2 * margin),
                          min(H - max(0, y - margin), hh + 2 * margin)))
    # CLI crop around "nmap -sV -A" or "sudo pacman -Syu"
    for t, x, y, w, h in meta_cli:
        if t.startswith("nmap") or t.startswith("sudo pacman"):
            crops.append((f"v5-zoom-100pct-cli.png", max(0, x - 40), max(0, y - 40),
                          min(W - max(0, x - 40), w + 80), min(H - max(0, y - 40), h + 80)))
            break
    # preview
    im.resize(1920 / W, kernel="lanczos3").jpegsave(str(DOCS / "laden-os-art-v5-preview-1920x1080.jpg"), Q=90)
    for name, x, y, w, h in crops:
        im.crop(x, y, w, h).pngsave(str(DOCS / name), compression=6)
        log(f"crop {name} {w}x{h}")
    return [c[0] for c in crops]


def build_release(master, downs, phones):
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
    hw = (OUT / "v5-hardware-eggs.txt").read_text()
    cli = (OUT / "v5-cli-eggs.txt").read_text()
    (RELEASE / "README.md").write_text(
        f"""# Laden OS Art v5

Calm emerald grid-tunnel art for Laden OS. LADEN letters only; deeper tunnel; crisp zoom-in hardware + CLI eggs.

## Files
32K / 8K / 4K / 3440 ultrawide / 2560 / 1920 / phone 1290x2796 + 1440x3200.

## Hidden hardware (emerald line-art, no vendor logos)
{hw}

## CLI microtext
{cli}

## Credits
Art direction: Laden AS / Laden OS
Pipeline: Real-ESRGAN anime + procedural layers + cairo vector eggs (post-upscale)

## License
LicenseRef-LadenAS — placeholder. https://laden.no
This pack is prepared locally and is NOT published.

## Verify
```
sha256sum -c SHA256SUMS
```
"""
    )
    import hashlib, zipfile
    lines = []
    for name in sorted(list(mapping.keys()) + ["README.md"]):
        p = RELEASE / name
        lines.append(f"{hashlib.sha256(p.read_bytes()).hexdigest()}  {name}")
    (RELEASE / "SHA256SUMS").write_text("\n".join(lines) + "\n")
    zip_path = RELEASE.parent / "Laden-OS-Art-v5.zip"
    if zip_path.exists():
        zip_path.unlink()
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for p in sorted(RELEASE.iterdir()):
            zf.write(p, arcname=f"Laden-OS-Art-v5/{p.name}")
    log(f"zip {zip_path} {zip_path.stat().st_size/1e6:.1f} MB")
    return zip_path


def main():
    if not MASTER.exists():
        raise SystemExit(f"missing {MASTER}")
    # Keep pristine pre-egg master for redo
    pristine = OUT / "laden-os-art-v5-deep-pre-eggs.png"
    if not pristine.exists():
        log("saving pristine pre-egg master…")
        shutil.copy2(MASTER, pristine)
    meta_hw, meta_cli = composite_overlays(pristine, MASTER)
    downs, phones = downscales_and_pack(MASTER)
    crops = zoom_crops(MASTER, meta_hw, meta_cli)
    build_release(MASTER, downs, phones)
    log("DONE crops=" + ",".join(crops))


if __name__ == "__main__":
    main()
