"""The kit.

Drums are the one part that is not a voice. They have no key, no register and
no chord to belong to: a pattern is a grid of hits, and what separates a style
is *which* hits, *how hard*, and *how far off the grid* they sit.

So this module is in three pieces, and the split matters:

- **The pattern** is written down, in `data/vocab/drums.json`. A backbeat on 2
  and 4, four on the floor, a one-drop, a tresillo — these are facts of a style,
  documented in every textbook, and are no more ownable than a scale. They are
  written the way `middaw/accompaniment.py` figures are written.
- **The feel** is measured, from the Groove MIDI Dataset (CC BY 4.0, 1,150
  performances by ten session drummers). How hard a kick is against a snare,
  how much quieter an off-beat hit is, how many snares are ghosted, and the
  fact that drummers play a hair *ahead* of the grid — none of that can be
  derived from theory, and all of it is in `docs/MEASUREMENTS.md`.
- **The variation** is rolled, from `middaw/chance.py`, like everything else.

Nothing from that corpus is copied. What crosses over is a handful of numbers.
"""

from __future__ import annotations

import json
import random
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path

from middaw.rhythm import apply_swing
from middaw.song import Note
from middaw.spec import MusicSpec

DRUMS_PATH = Path(__file__).resolve().parent.parent / "data" / "vocab" / "drums.json"

#: MIDI channel 10, counted from zero. The one channel where a note number is
#: an instrument rather than a pitch.
DRUM_CHANNEL = 9

#: How a pattern is written. A hit is an accent, a normal stroke or a ghost.
ACCENT, NORMAL, GHOST, REST = "X", "x", "o", "."

STROKE_VELOCITY = {ACCENT: 1.0, NORMAL: 0.74, GHOST: 0.38}

#: Relative loudness per instrument, as a fraction of the piece's base
#: velocity. Measured over 470,000 hits with `tools/measure_groove.py`: toms,
#: bells and open hi-hats are hit hard, kicks and rim clicks surprisingly
#: softly, and the spread between them is wider than any rule would guess.
INSTRUMENT_VELOCITY = {
    "kick": 0.75, "snare": 0.87, "hat": 0.89, "pedalhat": 0.84,
    "openhat": 1.09, "ride": 0.92, "bell": 1.17, "crash": 0.99,
    "splash": 1.21, "tom": 1.12, "hitom": 1.23, "lowtom": 1.12,
    "rim": 0.76, "clap": 0.87, "shaker": 0.70, "cowbell": 0.90,
    "conga": 0.80, "hiconga": 0.80, "clave": 0.85, "tambourine": 0.70,
    "woodblock": 0.85, "timbale": 0.95, "agogo": 0.85, "cabasa": 0.70,
    "maraca": 0.70, "triangle": 0.75,
}

#: A hit off the beat is about three quarters as loud as one on it — snare
#: 61 against 81, kick 53 against 64, hi-hat 63 against 81. This one number is
#: most of what makes a played bar sound different from a programmed one.
OFF_BEAT = 0.78

#: How far a hit scatters around the grid, in sixteenths.
#:
#: **Not** a systematic rush. The first run of this measurement said every
#: drummer on the record played five hundredths of a sixteenth early, in every
#: style, on every instrument — which is exactly the kind of suspiciously tidy
#: result that turns out to be the measurement's own fault. It was: a recorded
#: take does not begin on beat zero, and nobody had found the grid before
#: measuring distance from it. Aligned properly the offset vanishes (+0.008 for
#: a snare, −0.001 for a kick) and what is left is the scatter, which is real.
TIMING_SPREAD = 0.19


@dataclass
class Pattern:
    """One bar of a kit part, as a grid of strokes per instrument."""

    name: str
    steps: int = 16
    lines: dict[str, str] = field(default_factory=dict)
    meters: tuple[str, ...] = ("4/4",)
    label: str = ""

    def hits(self, instrument: str) -> str:
        return self.lines.get(instrument, "")


@lru_cache(maxsize=1)
def load_kit(path: str | None = None) -> dict:
    with open(Path(path) if path else DRUMS_PATH, "r", encoding="utf-8") as fh:
        return json.load(fh)


def kit_note(instrument: str) -> int | None:
    """The General MIDI note number that plays this instrument."""
    return load_kit()["kit"].get(instrument)


def patterns() -> dict[str, Pattern]:
    data = load_kit()
    return {name: Pattern(name=name, steps=entry.get("steps", 16),
                          lines={k: v for k, v in entry.items()
                                 if k not in ("steps", "meters", "label")},
                          meters=tuple(entry.get("meters", ("4/4",))),
                          label=entry.get("label", name))
            for name, entry in data["patterns"].items()}


def fills() -> dict[str, Pattern]:
    data = load_kit()
    return {name: Pattern(name=name, steps=entry.get("steps", 16),
                          lines={k: v for k, v in entry.items()
                                 if k not in ("steps", "meters", "label")},
                          meters=tuple(entry.get("meters", ("4/4",))),
                          label=entry.get("label", name))
            for name, entry in data.get("fills", {}).items()}


def pattern_for(spec: MusicSpec, rng: random.Random) -> Pattern | None:
    """The beat this piece plays: what the prompt asked for, else the style's.

    Returns None when nothing fits the meter, which is an answer rather than a
    failure: a 7/8 prog-rock beat is not in the book yet, and silence is better
    than a four-four backbeat stretched over it.
    """
    library = patterns()
    meter = f"{spec.meter[0]}/{spec.meter[1]}"
    wanted = getattr(spec, "drum_pattern", "") or ""
    if wanted in library and meter in library[wanted].meters:
        return library[wanted]

    weights: dict[str, float] = {}
    for genre in spec.genres:
        for name, weight in (load_kit()["genres"].get(genre) or {}).items():
            if name in library and meter in library[name].meters:
                weights[name] = weights.get(name, 0.0) + float(weight)
    if not weights:
        fallback = load_kit()["default_by_meter"].get(meter)
        return library.get(fallback) if fallback else None

    total = sum(weights.values())
    roll = rng.random() * total
    for name, weight in weights.items():
        roll -= weight
        if roll <= 0:
            return library[name]
    return library[next(iter(weights))]


def fill_for(pattern: Pattern, rng: random.Random) -> Pattern | None:
    """A fill in the same meter as the beat it interrupts."""
    candidates = [f for f in fills().values()
                  if set(f.meters) & set(pattern.meters)]
    return rng.choice(candidates) if candidates else None


def generate_drums(spec: MusicSpec, bars: int, rng: random.Random,
                   pattern: Pattern | None = None,
                   phrase: int = 4) -> list[Note]:
    """Play `bars` of the style's beat, with a fill at the end of a phrase."""
    pattern = pattern or pattern_for(spec, rng)
    if pattern is None or not pattern.lines:
        return []

    beats_per_bar = spec.beats_per_bar
    step_beats = beats_per_bar / pattern.steps
    chances = spec.chances
    notes: list[Note] = []

    for bar in range(bars):
        playing = pattern
        closing = (bar + 1) % phrase == 0 and bar + 1 < bars
        if closing and rng.random() < chances.drum_fill:
            playing = fill_for(pattern, rng) or pattern
        notes += _play_bar(spec, playing, bar * beats_per_bar, step_beats, rng)
    return notes


def _play_bar(spec: MusicSpec, pattern: Pattern, start: float,
              step_beats: float, rng: random.Random) -> list[Note]:
    notes: list[Note] = []
    per_beat = max(1, int(round(1.0 / step_beats))) if step_beats else 4
    for instrument, line in pattern.lines.items():
        note_number = kit_note(instrument)
        if note_number is None:
            continue
        loudness = INSTRUMENT_VELOCITY.get(instrument, 0.8)
        for index, stroke in enumerate(line[:pattern.steps]):
            if stroke == REST or stroke not in STROKE_VELOCITY:
                continue
            if stroke == GHOST and rng.random() > spec.chances.ghost_note:
                continue
            beat = start + index * step_beats
            # Swing moves the off-beat subdivisions; the style says how far.
            beat = start + apply_swing(beat - start, spec.swing, spec.meter)
            beat += rng.gauss(0, TIMING_SPREAD) * step_beats * spec.humanize
            on_beat = index % per_beat == 0
            velocity = spec.velocity * loudness * STROKE_VELOCITY[stroke]
            velocity *= 1.0 if on_beat else OFF_BEAT
            velocity += rng.gauss(0, 4) * spec.humanize
            notes.append(Note(start=max(0.0, round(beat, 5)),
                              duration=0.12,
                              pitch=note_number,
                              velocity=max(1, min(127, int(round(velocity))))))
    notes.sort(key=lambda n: (n.start, n.pitch))
    return notes


def grid_of(notes: list[Note], beats_per_bar: float, steps: int = 16) -> dict:
    """Fold a drum part back into hits per grid position, for measuring."""
    from collections import Counter
    classes = load_kit()["classes"]
    counts: dict[str, Counter] = {}
    for note in notes:
        name = classes.get(str(note.pitch))
        if not name:
            continue
        position = int(round((note.start % beats_per_bar) / beats_per_bar * steps))
        counts.setdefault(name, Counter())[position % steps] += 1
    return counts
