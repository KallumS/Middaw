"""Write the fixtures the Swift tests hold the native core to.

The Python is the reference: key signatures and spellings from the ScaleView
port, and Standard MIDI Files byte for byte from middaw/midi.py. Run it after
changing either, and commit what it writes.

    python3 tools/make_swift_fixtures.py
"""

from __future__ import annotations

import base64
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from middaw.midi import _key_signature_bytes, song_to_bytes   # noqa: E402
from middaw.scaleview import ROOTS, SCALES, Key                 # noqa: E402
from middaw.song import Control, Note, Song, Track              # noqa: E402

OUT = ROOT / "mac" / "Tests" / "MiddawCoreTests" / "Fixtures"

# The DAW's sixteen scales, in ScaleView's order (its menu's order).
DAW_SCALES = ["major", "minor", "harmonic_minor", "ionian", "dorian", "phrygian", "lydian",
              "mixolydian", "aeolian", "major_pentatonic", "minor_pentatonic", "major_blues",
              "blues", "whole_tone", "diminished_wh", "diminished_hw"]


def keys():
    out = []
    for r, root in enumerate(ROOTS):
        for s, scale_id in enumerate(DAW_SCALES):
            key = Key(root, scale_id)
            sig = _key_signature_bytes(key.label)
            out.append({"root": r + 1, "scale": s + 1, "label": key.label,
                        "names": [key.names[pc] for pc in range(12)],
                        "sharpsOrFlats": struct_signed(sig[0]), "minor": sig[1]})
    return out


def struct_signed(b: int) -> int:
    return b - 256 if b > 127 else b


SONGS = [
    {"name": "plain", "tempo": 120, "meter": [4, 4], "root": 1, "scale": 1,
     "tracks": [{"name": "Piano", "channel": 0, "program": 0,
                 "notes": [[0, 1, 60, 100], [1, 1, 64, 90], [2, 2, 67, 80]], "controls": []}]},
    {"name": "flats, odd meter, rounding", "tempo": 97, "meter": [7, 8], "root": 16, "scale": 2,
     "tracks": [{"name": "Melody", "channel": 0, "program": 0,
                 "notes": [[0.5 / 480, 0.25, 70, 64.7], [1.5 / 480, 0.5, 72, 127.9], [3.333333, 0.1, 74, 0],
                           [5, 1e-6, 75, 50], [6, 0.5, 130, 200]],
                 "controls": [[0, 11, 40], [0, 1, 0], [2.5, 64, 127], [3.0001, 11, 300]]},
                {"name": "Kit", "channel": 9, "program": 0,
                 "notes": [[0, 0.25, 36, 110], [0, 0.25, 42, 80], [1, 0.25, 38, 100], [1, 0.25, 36, 90]],
                 "controls": []}]},
    {"name": "repeated notes retrigger, unicode name", "tempo": 60, "meter": [3, 4], "root": 9, "scale": 5,
     "tracks": [{"name": "Violin I — détaché " + "x" * 80, "channel": 2, "program": 40,
                 "notes": [[0, 1, 62, 90], [1, 1, 62, 90], [1, 0.5, 66, 80], [2.75, 0.25, 69, 70]],
                 "controls": [[1, 7, 100]]}]},
]


def songs():
    out = []
    for spec in SONGS:
        key = Key(ROOTS[spec["root"] - 1], DAW_SCALES[spec["scale"] - 1])
        song = Song(tempo=spec["tempo"], meter=tuple(spec["meter"]), key_name=key.label)
        for t in spec["tracks"]:
            song.tracks.append(Track(
                name=t["name"], channel=t["channel"], program=t["program"],
                notes=[Note(start=s, duration=d, pitch=p, velocity=v) for s, d, p, v in t["notes"]],
                controls=[Control(start=s, controller=c, value=v) for s, c, v in t["controls"]]))
        # Numbers as exact hex floats: a JSON reader may land a decimal one
        # ulp away, and these are exactly the values where rounding decides.
        exact = dict(spec, tracks=[dict(t, notes=[[float(x).hex() for x in n] for n in t["notes"]],
                                         controls=[[float(x).hex() for x in c] for c in t["controls"]])
                                   for t in spec["tracks"]])
        out.append(dict(exact, midi=base64.b64encode(song_to_bytes(song)).decode()))
    return out


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "keys.json").write_text(json.dumps(keys(), indent=1, ensure_ascii=False) + "\n")
    (OUT / "midi.json").write_text(json.dumps(songs(), indent=1, ensure_ascii=False) + "\n")
    print("wrote", OUT)
