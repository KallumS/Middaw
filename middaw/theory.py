"""Pitch, scale and chord primitives.

Everything here is deliberately plain integer maths on MIDI note numbers so the
generator stays dependency-free and easy to test.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from middaw.scaleview import SCALES as SCALEVIEW_SCALES
from middaw.scaleview import (FLAT_NAMES, Key, detect_chord, key_for, spell_as)

PITCH_CLASSES = {
    "C": 0, "C#": 1, "DB": 1, "D": 2, "D#": 3, "EB": 3, "E": 4, "FB": 4,
    "E#": 5, "F": 5, "F#": 6, "GB": 6, "G": 7, "G#": 8, "AB": 8, "A": 9,
    "A#": 10, "BB": 10, "B": 11, "CB": 11,
}

NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

# Scale intervals come from the ScaleView port, so the two projects cannot
# disagree about what a mode is. `middaw.scaleview` also carries the letter
# each degree is spelled with, which is what `key_for` uses for names.
SCALES = {mode: scale.intervals for mode, scale in SCALEVIEW_SCALES.items()}

# Reduced scales borrow their harmony from a parent seven-note scale.
PARENT_SCALE = {
    "major_pentatonic": "major",
    "minor_pentatonic": "minor",
    "blues": "minor",
    "major_blues": "major",
}

MINOR_MODES = {"minor", "aeolian", "harmonic_minor", "melodic_minor",
               "dorian", "phrygian", "locrian", "minor_pentatonic", "blues",
               "diminished_wh"}

# The blues scales are minor-ish melodically and dominant harmonically: the
# b3 and b5 are blue notes sounded *against* I7, IV7 and V7, not evidence of a
# minor key. Modes listed here take their harmony from mixolydian as well as
# from their own parent, and a progression over them may be of either tonality.
BLUES_MODES = {"blues", "major_blues"}

# Chord quality -> semitone offsets from the chord root.
QUALITIES = {
    "maj": (0, 4, 7),
    "min": (0, 3, 7),
    "dim": (0, 3, 6),
    "aug": (0, 4, 8),
    "sus2": (0, 2, 7),
    "sus4": (0, 5, 7),
    "maj7": (0, 4, 7, 11),
    "min7": (0, 3, 7, 10),
    "dom7": (0, 4, 7, 10),
    "min7b5": (0, 3, 6, 10),
    "dim7": (0, 3, 6, 9),
    "maj6": (0, 4, 7, 9),
    "min6": (0, 3, 7, 9),
    "maj9": (0, 4, 7, 11, 14),
    "min9": (0, 3, 7, 10, 14),
    "dom9": (0, 4, 7, 10, 14),
    "add9": (0, 4, 7, 14),
    "minadd9": (0, 3, 7, 14),
    # Stacking thirds inside harmonic and melodic minor produces these, and
    # without them a minor tonic seventh silently reads as a major triad.
    "minmaj7": (0, 3, 7, 11),
    "augmaj7": (0, 4, 8, 11),
    "aug7": (0, 4, 8, 10),
}

# Suffix written on a roman numeral -> quality lookup. Resolution depends on
# whether the numeral itself is major (upper case) or minor (lower case).
_SUFFIX_MAP = {
    "": {"maj": "maj", "min": "min", "dim": "dim", "aug": "aug"},
    "7": {"maj": "dom7", "min": "min7", "dim": "min7b5", "aug": "dom7"},
    # On a lower-case numeral 'maj7' means a minor triad carrying a major
    # seventh - i minMaj7, the tonic of harmonic minor - not a major seventh.
    "maj7": {"maj": "maj7", "min": "minmaj7", "dim": "minmaj7", "aug": "augmaj7"},
    "+maj7": {k: "augmaj7" for k in ("maj", "min", "dim", "aug")},
    "+7": {k: "aug7" for k in ("maj", "min", "dim", "aug")},
    "m7": {"maj": "min7", "min": "min7", "dim": "min7b5", "aug": "min7"},
    "6": {"maj": "maj6", "min": "min6", "dim": "min6", "aug": "maj6"},
    "9": {"maj": "dom9", "min": "min9", "dim": "min9", "aug": "dom9"},
    "maj9": {"maj": "maj9", "min": "maj9", "dim": "maj9", "aug": "maj9"},
    "add9": {"maj": "add9", "min": "minadd9", "dim": "minadd9", "aug": "add9"},
    "sus2": {k: "sus2" for k in ("maj", "min", "dim", "aug")},
    "sus4": {k: "sus4" for k in ("maj", "min", "dim", "aug")},
    "o": {k: "dim" for k in ("maj", "min", "dim", "aug")},
    "o7": {k: "dim7" for k in ("maj", "min", "dim", "aug")},
    "0": {k: "min7b5" for k in ("maj", "min", "dim", "aug")},
    "+": {k: "aug" for k in ("maj", "min", "dim", "aug")},
}

_DEGREE_VALUES = {"I": 0, "II": 1, "III": 2, "IV": 3, "V": 4, "VI": 5, "VII": 6}

# Semitones above the tonic -> how that degree is written. Accidentals are
# measured against the major scale, which is why bVII is the subtonic in both
# C major and C minor.
ROMAN_BY_INTERVAL = {0: "I", 1: "bII", 2: "II", 3: "bIII", 4: "III", 5: "IV",
                     6: "bV", 7: "V", 8: "bVI", 9: "VI", 10: "bVII", 11: "VII"}

PLAIN_NUMERALS = ("I", "II", "III", "IV", "V", "VI", "VII")
MAJOR_INTERVALS = (0, 2, 4, 5, 7, 9, 11)


def roman_for_degree(degree: int, interval: int) -> str:
    """Spell a scale degree against the major scale: lydian's 4th is #IV.

    Naming by semitone alone cannot do this - six semitones above the tonic is
    bV in locrian and #IV in lydian, and which one it is depends on the degree
    it occupies, not on the pitch.
    """
    degree %= 7
    delta = (interval - MAJOR_INTERVALS[degree]) % 12
    if delta > 6:
        delta -= 12
    accidental = {-2: "bb", -1: "b", 0: "", 1: "#", 2: "x"}.get(delta)
    if accidental is None:
        return ROMAN_BY_INTERVAL[interval % 12]
    return accidental + PLAIN_NUMERALS[degree]

_ROMAN_RE = re.compile(
    r"^(?P<accidental>[b#]?)(?P<numeral>i{1,3}|iv|vi{0,2}|I{1,3}|IV|VI{0,2})"
    r"(?P<suffix>\+maj7|\+7|maj7|maj9|add9|sus2|sus4|m7|o7|[679]|o|0|\+)?"
    r"(?:/(?P<secondary>[b#]?(?:i{1,3}|iv|vi{0,2}|I{1,3}|IV|VI{0,2})))?$"
)


def parse_note_name(name: str) -> int:
    """'C', 'f#', 'Bb' -> pitch class 0-11."""
    key = name.strip().upper().replace("♭", "B").replace("♯", "#")
    if key not in PITCH_CLASSES:
        raise ValueError(f"unknown note name: {name!r}")
    return PITCH_CLASSES[key]


def note_name(pitch: int) -> str:
    """MIDI note number -> scientific pitch name, e.g. 60 -> 'C4'."""
    return f"{NOTE_NAMES[pitch % 12]}{pitch // 12 - 1}"


def scale_pitch_classes(tonic: int, mode: str) -> tuple[int, ...]:
    intervals = SCALES.get(mode, SCALES["major"])
    return tuple((tonic + i) % 12 for i in intervals)


def is_minor(mode: str) -> bool:
    return mode in MINOR_MODES


@dataclass(frozen=True)
class Chord:
    """A realised chord: absolute pitch classes plus a bass pitch class."""

    symbol: str
    root: int                      # pitch class of the chord root
    quality: str
    pitch_classes: tuple[int, ...]
    bass: int

    @property
    def tones(self) -> tuple[int, ...]:
        return self.pitch_classes

    def voice(self, low: int = 48, high: int = 72) -> list[int]:
        """Spell the chord as MIDI notes inside [low, high], root-position-ish."""
        notes: list[int] = []
        base = low + ((self.bass - low) % 12)
        notes.append(base)
        prev = base
        for pc in self.pitch_classes:
            if pc == self.bass and len(notes) == 1:
                continue
            candidate = prev + ((pc - prev) % 12)
            if candidate == prev:
                candidate += 12
            if candidate > high:
                candidate -= 12
                if candidate <= prev:
                    continue
            notes.append(candidate)
            prev = candidate
        return sorted(set(notes))

    def nearest_tone(self, pitch: int) -> int:
        """Closest chord tone to `pitch`, preserving register."""
        best, best_dist = pitch, 128
        for pc in self.pitch_classes:
            for octave in range(-1, 2):
                cand = pitch + ((pc - pitch) % 12) + 12 * octave
                dist = abs(cand - pitch)
                if dist < best_dist:
                    best, best_dist = cand, dist
        return best


def parse_roman(symbol: str, tonic: int, mode: str) -> Chord:
    """Turn a roman numeral such as 'iv', 'bVII', 'V7/vi' into a `Chord`."""
    match = _ROMAN_RE.match(symbol.strip())
    if not match:
        raise ValueError(f"unparsable roman numeral: {symbol!r}")

    numeral = match.group("numeral")
    accidental = match.group("accidental")
    suffix = match.group("suffix") or ""
    secondary = match.group("secondary")

    local_tonic, local_mode = tonic, mode
    if secondary:
        target = parse_roman(secondary, tonic, mode)
        local_tonic = target.root
        local_mode = "minor" if target.quality.startswith("min") else "major"

    # Roman numeral degrees are always measured against the MAJOR scale of the
    # local tonic; an accidental prefix is what lowers or raises them. That is
    # why 'bVII' is the subtonic in both C major and C minor, and why 'V7' in a
    # minor key correctly carries a raised leading tone.
    scale = scale_pitch_classes(local_tonic, "major")
    degree = _DEGREE_VALUES[numeral.upper()]
    root = scale[degree % len(scale)]
    if accidental == "b":
        root = (root - 1) % 12
    elif accidental == "#":
        root = (root + 1) % 12

    if numeral.isupper():
        base_quality = "aug" if suffix == "+" else "maj"
    else:
        base_quality = "dim" if suffix in ("o", "o7", "0") else "min"
    quality = _SUFFIX_MAP.get(suffix, _SUFFIX_MAP[""])[base_quality]

    pcs = tuple((root + i) % 12 for i in QUALITIES[quality])
    return Chord(symbol=symbol, root=root, quality=quality, pitch_classes=pcs, bass=root)


def harmonic_pitch_classes(tonic: int, mode: str) -> set[int]:
    """Pitch classes a chord may use in this key without sounding borrowed.

    Minor-ish modes also admit the raised leading tone, because a dominant
    seventh is idiomatic there rather than chromatic.
    """
    parent = PARENT_SCALE.get(mode, mode)
    allowed = set(scale_pitch_classes(tonic, parent))
    if mode in BLUES_MODES:
        allowed |= set(scale_pitch_classes(tonic, "mixolydian"))
    if is_minor(mode):
        allowed.add((tonic + 11) % 12)
    return allowed


def degree_to_pitch(scale: tuple[int, ...], tonic_octave_root: int, degree: int) -> int:
    """Scale degree (0-based, may be negative or > len) -> MIDI note number."""
    size = len(scale)
    octave, index = divmod(degree, size)
    pc = scale[index]
    root_pc = scale[0]
    offset = (pc - root_pc) % 12
    return tonic_octave_root + offset + 12 * octave


def nearest_degree(scale: tuple[int, ...], tonic_octave_root: int, pitch: int) -> int:
    """Inverse of `degree_to_pitch`, snapping to the closest in-scale degree."""
    best_degree, best_dist = 0, 128
    span = len(scale) * 4
    for degree in range(-span, span):
        dist = abs(degree_to_pitch(scale, tonic_octave_root, degree) - pitch)
        if dist < best_dist:
            best_degree, best_dist = degree, dist
    return best_degree
