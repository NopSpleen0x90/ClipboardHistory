#!/usr/bin/env python3
"""
Genera background.png per il DMG di ClipboardHistory.
Usa solo librerie built-in (struct, zlib).
"""
import struct, zlib, sys, os

def make_png(path: str, width: int = 540, height: int = 380):
    def pack_chunk(name: bytes, data: bytes) -> bytes:
        payload = name + data
        crc = zlib.crc32(payload) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + payload + struct.pack(">I", crc)

    # IHDR: 8-bit RGB
    ihdr_data = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    ihdr = pack_chunk(b"IHDR", ihdr_data)

    # Pixel data — gradiente scuro (stile macOS dark: blu-grigio)
    rows = bytearray()
    for y in range(height):
        rows.append(0)  # filter = None
        fy = y / (height - 1)
        for x in range(width):
            fx = x / (width - 1)
            # Colori: angolo top-left #1a1f2e → bottom-right #2d3561
            r = int(26  + fx * 21 + fy * 14)   # 26 → 61
            g = int(31  + fx * 30 + fy * 22)   # 31 → 83
            b = int(46  + fx * 45 + fy * 37)   # 46 → 128
            rows += bytes([min(r, 255), min(g, 255), min(b, 255)])

    idat = pack_chunk(b"IDAT", zlib.compress(bytes(rows), 9))
    iend = pack_chunk(b"IEND", b"")

    signature = b"\x89PNG\r\n\x1a\n"
    with open(path, "wb") as f:
        f.write(signature + ihdr + idat + iend)
    print(f"  ✓ {path}  ({width}×{height}px)")

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "background.png"
    os.makedirs(os.path.dirname(out) if os.path.dirname(out) else ".", exist_ok=True)
    make_png(out)
