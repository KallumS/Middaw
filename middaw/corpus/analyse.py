"""Read a MIDI file and derive tier-2 labels from it.

Nothing in here is a matter of opinion, which is the point: every field it
produces can be recomputed from the file, so the dataset cannot drift and two
annotators cannot disagree. Chord symbols come from the ScaleView reader, the
same routine the generator uses to name what it writes.
"""

from __future__ import annotations

import math
import re
from collections import Counter, defaultdict
from typing import NamedTuple

from middaw.midi import MidiFile, read_midi
from middaw.scaleview import Key, detect_chord, key_for
from middaw.song import Note
from middaw.theory import ROMAN_BY_INTERVAL, SCALES

# Krumhansl-Schmuckler key profiles.
MAJOR_PROFILE = (6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88)
MINOR_PROFILE = (6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17)

GRID = (1.0, 0.75, 2 / 3, 0.5, 1 / 3, 0.25, 1 / 6)

# Which pitch classes count as the harmony over a span: everything that sounds
# for at least this share of the longest one, up to this many notes. Both were
# swept against 1,041 human-analysed chords - see `middaw/corpus/measure.py`.
CLASS_SHARE = 0.2
MAX_CLASSES = 6


def _correlate(weights: list[float], profile: tuple[float, ...], rotation: int) -> float:
    rotated = [profile[(i - rotation) % 12] for i in range(12)]
    n = 12
    mean_w = sum(weights) / n
    mean_p = sum(rotated) / n
    num = sum((weights[i] - mean_w) * (rotated[i] - mean_p) for i in range(n))
    den = math.sqrt(sum((weights[i] - mean_w) ** 2 for i in range(n))
                    * sum((rotated[i] - mean_p) ** 2 for i in range(n)))
    return num / den if den else 0.0


# Which mode a collection makes when each of its degrees is taken as the tonic.
MODE_BY_DEGREE = ("major", "dorian", "phrygian", "lydian", "mixolydian",
                  "minor", "locrian")
# How likely each of those is a priori: most music is major or minor, and a
# locrian tonic is close to unheard of.
MODE_PRIOR = (0.96, 0.40, 0.16, 0.32, 0.40, 0.96, 0.0)


def detect_key(notes: list[Note]) -> tuple[int, str, float]:
    """Find the key in two steps: the collection, then the tonic inside it.

    Correlating against major and minor profiles alone cannot separate a key
    from its relative - A minor and C major are the same seven notes, and D
    dorian is those notes again - so pitch content is used only to pick the
    seven-note collection. Which of its degrees is the tonic is then settled by
    what the bass rests on, which is what a listener uses. Doing it in that
    order is what lets the labeller write "D Dorian" instead of "C Major".

    Returns (tonic, mode, confidence), confidence being the share of sounding
    time that falls inside the chosen collection.

    The weights below were swept against generated pieces, and the whole thing
    is now also measured against 410 Bach chorales and the analyses of eighteen
    of them (`middaw/corpus/measure.py`): it names tonic and mode exactly for
    about three quarters of the chorales and finds the tonic for four fifths.
    The weights themselves were left alone after that measurement, because
    every change to them bought a point on one set and lost one on the other,
    which is what noise looks like.

    The residue is not all error: some of it is four-bar vamps that never state
    a tonic (i-bVII-i-bVII is as much G mixolydian as D dorian), and some is a
    minor-key piece named as one of its modes, because the collection is chosen
    from the major scale and a raised leading tone moves it. Treat a low
    `key_confidence`, or a disagreement with the tag, as a file to look at by
    hand rather than a fact.
    """
    weights = [0.0] * 12
    for note in notes:
        weights[note.pitch % 12] += note.duration
    total = sum(weights)
    if total <= 0:
        return 0, "major", 0.0

    major = SCALES["major"]
    best_root, best_coverage, best_correlation = 0, -1.0, -2.0
    for root in range(12):
        collection = [(root + i) % 12 for i in major]
        coverage = sum(weights[pc] for pc in collection) / total
        correlation = _correlate(weights, MAJOR_PROFILE, root)
        if (coverage, correlation) > (best_coverage, best_correlation):
            best_root, best_coverage, best_correlation = root, coverage, correlation

    first_bass = _bass_pitch_class(notes, at_end=False)
    last_bass = _final_bass_pitch_class(notes)
    bass_roots = _bass_root_counts(notes)
    bass_total = sum(bass_roots.values()) or 1
    peak = max(weights) or 1.0

    best = (best_root, "major", -9.0)
    for degree, interval in enumerate(major):
        tonic = (best_root + interval) % 12
        score = (MODE_PRIOR[degree]
                 + 4.0 * bass_roots.get(tonic, 0) / bass_total
                 + 1.5 * weights[tonic] / peak
                 + (2.0 if tonic == last_bass else 0.0)
                 + (1.2 if tonic == first_bass else 0.0))
        if score > best[2]:
            best = (tonic, MODE_BY_DEGREE[degree], score)

    return best[0], best[1], round(best_coverage, 4)


def _bass_root_counts(notes: list[Note], window: float = 2.0) -> dict[int, int]:
    """How often each pitch class is the lowest note of a window.

    A loop that never cadences still states its tonic more often than anything
    else in the bass, so counting every bar beats trusting only the last one.
    """
    if not notes:
        return {}
    span = max(n.end for n in notes)
    counts: dict[int, int] = {}
    position = 0.0
    while position < span:
        sounding = [n for n in notes
                    if n.start < position + window and n.end > position]
        if sounding:
            pitch_class = min(sounding, key=lambda n: n.pitch).pitch % 12
            counts[pitch_class] = counts.get(pitch_class, 0) + 1
        position += window
    return counts


def _bass_pitch_class(notes: list[Note], at_end: bool) -> int | None:
    """The lowest note of the first or last bar-ish window."""
    if not notes:
        return None
    span = max(n.end for n in notes)
    window = [n for n in notes if n.start >= span - 4.0] if at_end \
        else [n for n in notes if n.start <= 4.0]
    if not window:
        return None
    return min(window, key=lambda n: n.pitch).pitch % 12


def _final_bass_pitch_class(notes: list[Note]) -> int | None:
    """The bass note of the *last chord*, which is the strongest evidence there
    is about the key.

    Not the lowest note of the last few beats: at a cadence the dominant often
    sits below the tonic that follows it, so a window catches the V and calls
    the piece a fifth away from where it ends. Measured against 410 Bach
    chorales and 120 generated pieces, reading the last chord instead of the
    last window moved key detection from 62% to 75% on the chorales and from
    51% to 73% on the generated set - the same change helping both, which is
    what tells you it is a fix rather than a tuning.
    """
    if not notes:
        return None
    span = max(n.end for n in notes)
    sounding = [n for n in notes if n.end >= span - 0.05 and n.start < span]
    if not sounding:
        return None
    return min(sounding, key=lambda n: n.pitch).pitch % 12


def _quantise(value: float) -> float:
    return min(GRID, key=lambda g: abs(g - value))


def rhythm_cells(notes: list[Note], beats_per_bar: float) -> Counter:
    """Onsets grouped into one-beat cells, as the generator's vocabulary sees them."""
    cells: Counter = Counter()
    by_beat: dict[int, list[float]] = defaultdict(list)
    for note in notes:
        by_beat[int(note.start)].append(note.start % 1.0)
    for beat, offsets in by_beat.items():
        offsets = sorted(set(round(o, 3) for o in offsets))
        if not offsets or offsets[0] > 0.05:
            continue
        durations = []
        for index, offset in enumerate(offsets):
            end = offsets[index + 1] if index + 1 < len(offsets) else 1.0
            durations.append(_quantise(end - offset))
        total = sum(durations)
        if 0.95 <= total <= 1.05:
            cells[tuple(durations)] += 1
    return cells


def melodic_intervals(notes: list[Note], tonic: int, mode: str) -> Counter:
    """Successive steps of the highest line, measured in scale degrees."""
    scale = SCALES.get(mode, SCALES["major"])
    degree_of: dict[int, int] = {}
    for index, interval in enumerate(scale):
        degree_of[(tonic + interval) % 12] = index

    line = _top_line(notes)
    steps: Counter = Counter()
    previous = None
    for note in line:
        degree = degree_of.get(note.pitch % 12)
        if degree is None:
            previous = None                     # a chromatic note breaks the chain
            continue
        absolute = degree + len(scale) * ((note.pitch - tonic) // 12)
        if previous is not None:
            step = absolute - previous
            if -9 <= step <= 9:
                steps[step] += 1
        previous = absolute
    return steps


def _top_line(notes: list[Note]) -> list[Note]:
    """The melody as a listener hears it: the highest note sounding at each onset."""
    by_onset: dict[float, list[Note]] = defaultdict(list)
    for note in notes:
        by_onset[round(note.start, 3)].append(note)
    return [max(group, key=lambda n: n.pitch) for _onset, group in sorted(by_onset.items())]


_ROOT_RE = re.compile(r"^([A-G][#b]?)")
_NAME_TO_PC = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4,
               "Fb": 4, "E#": 5, "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8,
               "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11, "Cb": 11}


def chord_progression(notes: list[Note], beats_per_bar: float, key: Key,
                      max_bars: int = 64) -> tuple[list[str], list[str]]:
    """Name each bar's harmony, and express it as a roman numeral in the key."""
    if not notes:
        return [], []
    last_beat = max(n.end for n in notes)
    bars = min(max_bars, max(1, int(math.ceil(last_beat / beats_per_bar))))

    symbols: list[str] = []
    romans: list[str] = []
    for bar in range(bars):
        start = bar * beats_per_bar
        named = name_window(notes, start, start + beats_per_bar, key)
        symbols.append(named.symbol)
        romans.append(named.roman)
    return symbols, romans


class WindowChord(NamedTuple):
    """What was sounding across a span, and what it is called."""

    symbol: str
    roman: str
    classes: tuple[int, ...]
    bass: int | None


def name_window(notes: list[Note], start: float, end: float,
                key: Key) -> WindowChord:
    """Name the harmony sounding across one span of time.

    A bar is the usual span, but an analyst's segmentation is a better one
    where it exists, which is what the measuring harness passes in.
    """
    weights: Counter = Counter()
    lowest: tuple[int, float] | None = None
    for note in notes:
        overlap = min(note.end, end) - max(note.start, start)
        if overlap <= 0:
            continue
        weights[note.pitch % 12] += overlap
        if lowest is None or note.pitch < lowest[0]:
            lowest = (note.pitch, note.start)
    if not weights:
        return WindowChord("", "", (), None)
    # Order by how long each pitch class actually sounds, so a passing
    # note cannot displace a chord tone that is held under it.
    ranked = weights.most_common()
    strongest = ranked[0][1]
    classes = [pc for pc, w in ranked
               if w >= strongest * CLASS_SHARE][:MAX_CLASSES]
    bass = lowest[0] % 12 if lowest else classes[0]
    symbol = detect_chord(classes, bass, key) or ""
    return WindowChord(symbol, _roman_for(symbol, classes, key),
                       tuple(classes), bass)


def symbol_root(symbol: str) -> int | None:
    """The pitch class a chord symbol is rooted on."""
    match = _ROOT_RE.match((symbol or "").split("/")[0])
    return _NAME_TO_PC.get(match.group(1)) if match else None


def _roman_for(symbol: str, classes, key: Key) -> str:
    """Best-effort roman numeral: degree from the root, case from the third."""
    if not symbol or " " in symbol:
        return ""
    match = _ROOT_RE.match(symbol.split("/")[0])
    if not match:
        return ""
    root = _NAME_TO_PC.get(match.group(1))
    if root is None:
        return ""
    interval = (root - key.tonic) % 12
    numeral = ROMAN_BY_INTERVAL[interval]
    intervals = {(pc - root) % 12 for pc in classes}
    minorish = 3 in intervals and 4 not in intervals
    if minorish:
        accidental = numeral[0] if numeral[0] == "b" else ""
        numeral = accidental + numeral[len(accidental):].lower()
    return numeral


def syncopation(notes: list[Note], beats_per_bar: float) -> float:
    """Share of onsets that fall off the beat."""
    if not notes:
        return 0.0
    off = sum(1 for n in notes if abs(n.start - round(n.start)) > 0.08)
    return round(off / len(notes), 4)


def swing_ratio(notes: list[Note]) -> float:
    """How far the offbeat eighths sit behind the grid; 0 is straight."""
    offsets = [n.start % 1.0 for n in notes if 0.3 < (n.start % 1.0) < 0.75]
    if len(offsets) < 8:
        return 0.0
    return round(max(0.0, (sum(offsets) / len(offsets)) - 0.5) * 2, 3)


def mean_polyphony(notes: list[Note]) -> float:
    if not notes:
        return 0.0
    total = sum(n.duration for n in notes)
    span = max(n.end for n in notes) - min(n.start for n in notes)
    return round(total / span, 3) if span else 0.0


def analyse_notes(notes: list[Note], tempo: float, meter: tuple[int, int]) -> dict:
    """Everything tier 2 holds, computed from a note list."""
    if not notes:
        return {"note_count": 0}
    beats_per_bar = meter[0] * 4.0 / meter[1]
    tonic, mode, confidence = detect_key(notes)
    key = key_for(tonic, mode)
    symbols, romans = chord_progression(notes, beats_per_bar, key)
    span = max(n.end for n in notes)
    pitches = [n.pitch for n in notes]
    velocities = [n.velocity for n in notes]

    return {
        "note_count": len(notes),
        "bars": int(math.ceil(span / beats_per_bar)),
        "beats": round(span, 3),
        "tempo": round(tempo, 2),
        "meter": f"{meter[0]}/{meter[1]}",
        "tonic": tonic,
        "mode": mode,
        "key": key.label,
        "key_confidence": confidence,
        "density": round(len(notes) / span, 3) if span else 0.0,
        "polyphony_mean": mean_polyphony(notes),
        "pitch_low": min(pitches),
        "pitch_high": max(pitches),
        "pitch_mean": round(sum(pitches) / len(pitches), 2),
        "velocity_mean": round(sum(velocities) / len(velocities), 2),
        "velocity_range": max(velocities) - min(velocities),
        "syncopation": syncopation(notes, beats_per_bar),
        "swing": swing_ratio(notes),
        "chords": symbols,
        "roman": romans,
        "intervals": {str(k): v for k, v in
                      melodic_intervals(notes, tonic, mode).most_common(24)},
        "rhythm_cells": {",".join(f"{d:.4g}" for d in cell): count
                         for cell, count in rhythm_cells(notes, beats_per_bar).most_common(24)},
    }


def analyse_file(path) -> dict:
    midi: MidiFile = read_midi(path)
    # Not `midi.notes`: a kick drum is note 36 on channel 10, and a key
    # detector handed a drum track will find C every time.
    return analyse_notes(midi.pitched_notes, midi.tempo, midi.meter)
