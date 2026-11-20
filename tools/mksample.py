"""Writes the SolidCraft 2000 sample parts in samples/.

    python3 tools/mksample.py

A part file is the TDesign record from src/modModel.bas, written by VB's
Put: no padding, little-endian, fixed-length strings padded with spaces.
"""
import struct
from pathlib import Path

MAX_FEATURES = 64
SKETCH_RECT, SKETCH_CIRCLE, EXTRUDE, REVOLVE, HOLE, FILLET = 1, 2, 3, 4, 5, 6
SM_BASE, SM_EDGE, SM_FLAT = 20, 21, 22


def fixed(s, n):
    return s.encode("latin-1").ljust(n, b" ")[:n]


def feature(kind=0, name="", x=0.0, y=0.0, z=0.0, p1=0.0, p2=0.0, ref=0, suppressed=0, p3=0.0, info=""):
    return (struct.pack("<h", kind) + fixed(name, 24) + struct.pack("<5d", x, y, z, p1, p2)
            + struct.pack("<hh", ref, suppressed) + struct.pack("<d", p3) + fixed(info, 32)
            + struct.pack("<3d", 0, 0, 0))


def part(title, features):
    body = b"".join(feature(**f) for f in features)
    body += feature() * (MAX_FEATURES - len(features))
    return b"SC2K" + struct.pack("<h", 6) + fixed(title, 64) + struct.pack("<h", len(features)) + body


plate = [
    dict(kind=SKETCH_RECT, name="Sketch1", x=-40, y=-25, p1=80, p2=50, p3=6),
    dict(kind=EXTRUDE, name="Extrude1", p1=6, ref=1),
    dict(kind=FILLET, name="Fillet1", p1=3, ref=2),
    dict(kind=HOLE, name="Hole1", x=-32, y=-17, p1=5, ref=2),
    dict(kind=HOLE, name="Hole2", x=32, y=-17, p1=5, ref=2),
    dict(kind=HOLE, name="Hole3", x=32, y=17, p1=5, ref=2),
    dict(kind=HOLE, name="Hole4", x=-32, y=17, p1=5, ref=2),
    dict(kind=SKETCH_CIRCLE, name="Sketch2", p1=10, ref=2),
    dict(kind=EXTRUDE, name="Extrude2", p1=15, ref=8),
    dict(kind=FILLET, name="Fillet2", p1=3, ref=9),
    dict(kind=HOLE, name="Hole5", p1=10, ref=9),
]

tray = [
    dict(kind=SKETCH_RECT, name="Sketch1", x=-50, y=-30, p1=100, p2=60),
    dict(kind=SM_BASE, name="BaseFlange1", p1=1.52, p2=1.52, p3=0.44, ref=1),
    dict(kind=SM_EDGE, name="EdgeFlange1", x=0, p1=15, p2=90, p3=1, ref=2),
    dict(kind=SM_EDGE, name="EdgeFlange2", x=1, p1=15, p2=90, p3=2, ref=2),
    dict(kind=SM_EDGE, name="EdgeFlange3", x=2, p1=15, p2=90, p3=1, ref=2),
    dict(kind=SM_EDGE, name="EdgeFlange4", x=3, p1=15, p2=90, p3=3, ref=2),
]

out = Path(__file__).resolve().parent.parent / "samples"
(out / "Filleted Plate.sc2").write_bytes(part("Filleted Plate", plate))
(out / "Sheet Metal Tray.sc2").write_bytes(part("Sheet Metal Tray", tray))
print("wrote", out / "Filleted Plate.sc2", "and", out / "Sheet Metal Tray.sc2")
