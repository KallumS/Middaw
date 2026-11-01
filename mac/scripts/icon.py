"""Draw Middaw's app icon as a PNG, with the standard library only.

ScaleView's octave in the house scheme: the key's seven notes lit on the
ground, the other five dark, and a C major triad ringed in the accent - the
same picture the toolbar shows while a chord sounds.

    python3 mac/scripts/icon.py out.png [size]
"""

from __future__ import annotations

import math
import struct
import sys
import zlib

GROUND = (0x23, 0x27, 0x2E)
LIT = (0xDD, 0xE1, 0xE7)
DARK = (0x3A, 0x40, 0x4A)
ACCENT = (0xFF, 0xF2, 0x00)


def _coverage(distance_inside: float) -> float:
    """How much of a pixel a shape covers, from how far inside its edge it is."""
    return max(0.0, min(1.0, distance_inside + 0.5))


def draw(size: int = 1024) -> bytes:
    s = size / 1024.0
    # Apple's grid: an 824-point rounded square in the middle of 1024.
    side, radius = 824 * s, 185 * s
    left = (size - side) / 2
    step = side / 8.2
    dot = step * 0.30
    ring_w = step * 0.075
    lit_white = [0, 1, 2, 3, 4, 5, 6]                 # C D E F G A B
    blacks = [0.5, 1.5, 3.5, 4.5, 5.5]                 # C# D# F# G# A#
    ringed = {0, 2, 4}                                  # C, E, G
    row_white, row_black = size / 2 + step * 0.62, size / 2 - step * 0.62
    x0 = size / 2 - step * 3
    circles = [(x0 + i * step, row_white, LIT, i in ringed) for i in lit_white]
    circles += [(x0 + b * step, row_black, DARK, False) for b in blacks]

    rows = []
    for y in range(size):
        row = bytearray([0])                            # PNG filter: none
        py = y + 0.5
        for x in range(size):
            px = x + 0.5
            # rounded square: signed distance inside its edge
            qx = abs(px - size / 2) - (side / 2 - radius)
            qy = abs(py - size / 2) - (side / 2 - radius)
            outside = math.hypot(max(qx, 0.0), max(qy, 0.0)) + min(max(qx, qy), 0.0) - radius
            inside = -outside
            alpha = _coverage(inside)
            r, g, b = GROUND
            for cx, cy, colour, ring in circles:
                d = math.hypot(px - cx, py - cy)
                if d > dot + ring_w * 3:
                    continue
                if ring:
                    a = _coverage(dot + ring_w * 2.2 - d) - _coverage(dot + ring_w * 0.9 - d)
                    if a > 0:
                        r, g, b = (r + (ACCENT[0] - r) * a, g + (ACCENT[1] - g) * a, b + (ACCENT[2] - b) * a)
                a = _coverage(dot - d)
                if a > 0:
                    r, g, b = (r + (colour[0] - r) * a, g + (colour[1] - g) * a, b + (colour[2] - b) * a)
            row += bytes((int(r + 0.5), int(g + 0.5), int(b + 0.5), int(alpha * 255 + 0.5)))
        rows.append(bytes(row))

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)   # 8-bit RGBA
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
            + chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b""))


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "Middaw.png"
    size = int(sys.argv[2]) if len(sys.argv) > 2 else 1024
    with open(out, "wb") as fh:
        fh.write(draw(size))
