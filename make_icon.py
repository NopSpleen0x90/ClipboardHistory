#!/usr/bin/env python3
"""
ClipboardHistory macOS icon generator.
Design: Modern minimalist — two overlapping clipboards on a rich purple-to-cyan gradient.
"""
import os, sys, math

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError:
    os.system(f"{sys.executable} -m pip install Pillow -q --break-system-packages")
    from PIL import Image, ImageDraw, ImageFilter


# ── Helpers ──────────────────────────────────────────────────────────────────

def lerp(a, b, t):
    return a + (b - a) * t

def lerp_color(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(lerp(c1[i], c2[i], t)) for i in range(4))

def alpha_composite_pixel(bg, fg):
    """Composite fg (RGBA) over bg (RGBA)."""
    fa = fg[3] / 255.0
    ba = bg[3] / 255.0
    oa = fa + ba * (1 - fa)
    if oa == 0:
        return (0, 0, 0, 0)
    out = []
    for i in range(3):
        out.append(int((fg[i]*fa + bg[i]*ba*(1-fa)) / oa))
    out.append(int(oa * 255))
    return tuple(out)

def paste_rgba(dst, layer):
    """Alpha-composite RGBA layer onto dst (RGBA Image)."""
    return Image.alpha_composite(dst, layer)

def draw_rrect(size, x0, y0, x1, y1, r, color):
    """Return a transparent RGBA layer with a filled rounded-rectangle."""
    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x0, y0, x1, y1, r = int(x0), int(y0), int(x1), int(y1), int(r)
    r = min(r, (x1-x0)//2, (y1-y0)//2)
    d.rectangle([x0+r, y0, x1-r, y1], fill=color)
    d.rectangle([x0, y0+r, x1, y1-r], fill=color)
    d.ellipse([x0, y0, x0+2*r, y0+2*r], fill=color)
    d.ellipse([x1-2*r, y0, x1, y0+2*r], fill=color)
    d.ellipse([x0, y1-2*r, x0+2*r, y1], fill=color)
    d.ellipse([x1-2*r, y1-2*r, x1, y1], fill=color)
    return layer


# ── Gradient background ───────────────────────────────────────────────────────

def make_bg(size, corner_r):
    """
    Diagonal gradient: top-left #5B2FD4 (deep violet) → bottom-right #06B6D4 (cyan).
    Clipped to rounded square.
    """
    c1 = (91,  47, 212, 255)   # deep violet
    c2 = (6,  182, 212, 255)   # cyan

    pixels = []
    for y in range(size):
        row = []
        for x in range(size):
            t = (x / (size-1) + y / (size-1)) / 2
            row.append(lerp_color(c1, c2, t))
        pixels.append(row)

    base = Image.new('RGBA', (size, size))
    for y, row in enumerate(pixels):
        for x, px in enumerate(row):
            base.putpixel((x, y), px)

    # Rounded mask
    mask = Image.new('L', (size, size), 0)
    md = ImageDraw.Draw(mask)
    r = int(corner_r)
    md.rectangle([r, 0, size-r, size], fill=255)
    md.rectangle([0, r, size, size-r], fill=255)
    md.ellipse([0, 0, 2*r, 2*r], fill=255)
    md.ellipse([size-2*r, 0, size, 2*r], fill=255)
    md.ellipse([0, size-2*r, 2*r, size], fill=255)
    md.ellipse([size-2*r, size-2*r, size, size], fill=255)

    result = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    result.paste(base, mask=mask)
    return result


# ── Icon composer ─────────────────────────────────────────────────────────────

def make_icon(size):
    sc = size / 1024.0  # scale factor

    # ── 1. Background ──────────────────────────────────────────
    img = make_bg(size, corner_r=size * 0.22)

    # ── 2. Shadow clipboard (rear copy, slightly offset) ───────
    off = 62 * sc
    rx0, ry0 = 230*sc + off, 185*sc + off
    rx1, ry1 = 760*sc + off, 840*sc + off
    rr  = 64*sc
    shadow = draw_rrect(size, rx0, ry0, rx1, ry1, rr, (255, 255, 255, 38))
    img = paste_rgba(img, shadow)

    # ── 3. Main clipboard body ─────────────────────────────────
    cx0, cy0 = 200*sc, 155*sc
    cx1, cy1 = 730*sc, 810*sc
    cr = 64*sc
    board = draw_rrect(size, cx0, cy0, cx1, cy1, cr, (255, 255, 255, 252))
    img = paste_rgba(img, board)

    # ── 4. Clipboard clamp ─────────────────────────────────────
    clamp_w  = 230*sc
    clamp_h  = 78*sc
    clamp_r  = 32*sc
    clamp_x0 = (size - clamp_w) / 2
    clamp_y0 = cy0 - clamp_h / 2
    # clamp body — gradient colour
    clamp_layer = draw_rrect(size, clamp_x0, clamp_y0,
                             clamp_x0+clamp_w, clamp_y0+clamp_h,
                             clamp_r, (78, 40, 200, 255))
    img = paste_rgba(img, clamp_layer)

    # clamp inner hole
    hw, hh = 110*sc, 38*sc
    hx = (size - hw) / 2
    hy = clamp_y0 + (clamp_h - hh) / 2
    hole_layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(hole_layer).ellipse([hx, hy, hx+hw, hy+hh],
                                        fill=(255, 255, 255, 180))
    img = paste_rgba(img, hole_layer)

    # ── 5. Content lines ───────────────────────────────────────
    line_color = (100, 60, 200, 100)
    lx0 = 285*sc
    line_h = 34*sc
    gap   = 88*sc
    start_y = 370*sc
    widths = [370*sc, 320*sc, 350*sc, 230*sc]

    for i, lw in enumerate(widths):
        ly = start_y + i * gap
        lr = line_h / 2
        line_layer = draw_rrect(size, lx0, ly, lx0+lw, ly+line_h, lr, line_color)
        img = paste_rgba(img, line_layer)

    # ── 6. "Copy" badge — small clipboard bottom-right ─────────
    # Positioned so it overlaps the corner of the main clipboard
    bs   = 245*sc          # badge total size
    bx0  = cx1 - 95*sc
    by0  = cy1 - 95*sc
    bx1  = bx0 + bs
    by1  = by0 + bs
    br   = 30*sc

    # Badge background: semi-transparent white pill
    badge_bg = draw_rrect(size, bx0, by0, bx1, by1, br, (255, 255, 255, 230))
    img = paste_rgba(img, badge_bg)

    # Badge clipboard body
    pad = 30*sc
    bb_x0, bb_y0 = bx0+pad, by0+pad+8*sc
    bb_x1, bb_y1 = bx1-pad, by1-pad
    bb_r = 14*sc
    badge_board = draw_rrect(size, bb_x0, bb_y0, bb_x1, bb_y1, bb_r,
                              (78, 40, 200, 220))
    img = paste_rgba(img, badge_board)

    # Badge clamp
    bc_w, bc_h = 60*sc, 20*sc
    bc_x0 = (bx0+bx1)/2 - bc_w/2
    bc_y0 = bb_y0 - bc_h/2
    badge_clamp = draw_rrect(size, bc_x0, bc_y0, bc_x0+bc_w, bc_y0+bc_h, 8*sc,
                              (255, 255, 255, 255))
    img = paste_rgba(img, badge_clamp)

    # Badge lines (3 tiny white lines)
    bl_x0 = bb_x0 + 14*sc
    bl_h  = 9*sc
    bl_gap = 20*sc
    bl_start = bb_y0 + 26*sc
    for i, blw_ratio in enumerate([0.68, 0.56, 0.62]):
        blw = (bb_x1 - bb_x0 - 28*sc) * blw_ratio
        bly = bl_start + i*bl_gap
        bl_layer = draw_rrect(size, bl_x0, bly, bl_x0+blw, bly+bl_h, bl_h/2,
                               (255, 255, 255, 200))
        img = paste_rgba(img, bl_layer)

    # ── 7. Subtle inner glow (top edge highlight) ──────────────
    glow = Image.new('RGBA', (size, size), (0,0,0,0))
    gd = ImageDraw.Draw(glow)
    gw = size * 0.7
    gh = size * 0.12
    gx = (size - gw) / 2
    gy = size * 0.04
    for i in range(int(gh)):
        alpha = int(40 * (1 - i/gh))
        gd.ellipse([gx, gy+i, gx+gw, gy+i+1], fill=(255,255,255,alpha))
    img = paste_rgba(img, glow)

    return img


# ── Iconset builder ───────────────────────────────────────────────────────────

ICONSET_SIZES = [16, 32, 64, 128, 256, 512, 1024]

def build_iconset(out_dir):
    iconset = os.path.join(out_dir, "AppIcon.iconset")
    os.makedirs(iconset, exist_ok=True)

    # Render all needed sizes first
    all_sizes = set(ICONSET_SIZES)
    cache = {}
    for s in sorted(all_sizes):
        print(f"  Rendering {s}×{s}…")
        cache[s] = make_icon(s)

    for base in ICONSET_SIZES:
        img = cache[base]
        fname = f"icon_{base}x{base}.png"
        img.save(os.path.join(iconset, fname))
        # @2x Retina: icon_{base}x{base}@2x.png uses the 2× size image
        double = base * 2
        if double in cache:
            fname2 = f"icon_{base}x{base}@2x.png"
            cache[double].save(os.path.join(iconset, fname2))

    print("  Converting iconset → .icns …")
    icns = os.path.join(out_dir, "AppIcon.icns")
    ret = os.system(f"iconutil -c icns '{iconset}' -o '{icns}'")
    if ret == 0:
        print(f"  ✅  {icns}")
    else:
        print("  ⚠️  iconutil failed (non-macOS?). Iconset kept.")
    return icns, iconset


if __name__ == "__main__":
    project = os.path.dirname(os.path.abspath(__file__))
    print("🎨  Generating ClipboardHistory icon…")
    icns_path, iconset_path = build_iconset(project)

    # Preview: save a 512px PNG for quick viewing
    preview = os.path.join(project, "icon_preview.png")
    make_icon(512).save(preview)
    print(f"👁   Preview: {preview}")
    print("Done.")
