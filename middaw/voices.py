"""Voices other than the melody, the chords and the bass.

A piece is not a tune over a chord pad. These are the lines that make a texture
contrapuntal rather than homophonic:

* **Countermelody** - a second melodic line, set against the first. It moves
  where the melody rests, moves *contrary* to it where it can, and never makes
  parallel fifths or octaves with it, which is the oldest rule in part writing
  and the one that keeps two lines sounding like two lines.
* **Ostinato** - one figure, stated and restated, refitted to each chord. The
  figure is invented once and then never varies, which is exactly what
  separates an ostinato from a melody.
* **Arpeggio** - the chord itself as a line rather than a block.
"""

from __future__ import annotations

import random

from middaw.accompaniment import _arpeggiate, _note, _voiced
from middaw.rhythm import apply_swing, bar_rhythm, pulse_length, pulses_per_bar
from middaw.song import Note
from middaw.spec import MusicSpec
from middaw.theory import Chord

PERFECT_INTERVALS = (0, 7)


def _melody_at(melody: list[Note], beat: float) -> Note | None:
    """The melody note sounding at a given beat, if any."""
    current = None
    for note in melody:
        if note.start <= beat + 1e-6 < note.end:
            current = note
        elif note.start > beat + 1e-6:
            break
    return current


def _makes_parallel(previous_counter: int | None, counter: int,
                    previous_melody: int | None, melody: int | None) -> bool:
    """Would this move make parallel fifths or octaves with the melody?"""
    if previous_counter is None or previous_melody is None or melody is None:
        return False
    if counter == previous_counter or melody == previous_melody:
        return False
    if (counter - previous_counter) * (melody - previous_melody) <= 0:
        return False                      # contrary or oblique motion is safe
    # Compare each voice against the other *at the same moment*: the interval
    # before the move, and the interval after it.
    before = abs(previous_melody - previous_counter) % 12
    after = abs(melody - counter) % 12
    return before == after and before in PERFECT_INTERVALS


def generate_countermelody(spec: MusicSpec, spans: list[tuple[float, float, Chord]],
                           melody: list[Note], rng: random.Random) -> list[Note]:
    """A second line under the melody, moving when the melody does not."""
    if not spans:
        return []
    melody = sorted(melody, key=lambda n: n.start)
    pulse = pulse_length(spec.meter)
    centre = 60 + spec.register * 3 - 2
    low, high = centre - 10, centre + 9

    notes: list[Note] = []
    previous_pitch: int | None = None
    previous_melody: int | None = None

    # A dense texture wants a second line that moves, not one that holds; a
    # sparse one wants the opposite.
    grid = pulse if spec.density < 0.55 else pulse / 2
    for start, length, chord in spans:
        steps = max(1, int(round(length / grid)))
        positions = [start + i * grid for i in range(steps)]

        # Move where the melody rests. If the melody is attacking everywhere,
        # fall back to the strong beats so the line does not vanish.
        free = [p for p in positions
                if not any(abs(n.start - p) < grid * 0.4 for n in melody)]
        # Complementary, but not to the point of disappearing. Where the
        # melody leaves no room the line simply moves with it - note against
        # note is first species, and the independence comes from the intervals.
        chosen = free if len(free) >= max(2, steps // 2) else positions

        for index, beat in enumerate(chosen):
            end = chosen[index + 1] if index + 1 < len(chosen) else start + length
            duration = max(grid * 0.5, end - beat)

            above = _melody_at(melody, beat)
            melody_pitch = above.pitch if above else None

            candidates = []
            for pitch_class in chord.pitch_classes:
                for octave in range(-1, 3):
                    pitch = low + ((pitch_class - low) % 12) + 12 * octave
                    if not low <= pitch <= high:
                        continue
                    if melody_pitch is not None and pitch >= melody_pitch - 2:
                        continue          # stay under the tune
                    candidates.append(pitch)
            if not candidates:
                continue

            def score(pitch: int) -> tuple:
                step = 0 if previous_pitch is None else abs(pitch - previous_pitch)
                contrary = 0
                if previous_pitch is not None and melody_pitch is not None \
                        and previous_melody is not None:
                    moved = melody_pitch - previous_melody
                    mine = pitch - previous_pitch
                    contrary = -1 if moved * mine < 0 else (0 if mine == 0 else 1)
                parallel = _makes_parallel(previous_pitch, pitch,
                                           previous_melody, melody_pitch)
                return (parallel, contrary, step, -pitch)

            pitch = min(candidates, key=score)
            notes.append(_note(spec, rng, apply_swing(beat, spec.swing, spec.meter),
                               duration * 0.94, pitch, -10))
            previous_pitch = pitch
            if melody_pitch is not None:
                previous_melody = melody_pitch
    return notes


def make_ostinato_figure(spec: MusicSpec, rng: random.Random) -> list[tuple[float, float, int]]:
    """Invent the figure once: (onset, duration, chord-tone index)."""
    rhythm = bar_rhythm(rng, spec.meter, min(0.85, spec.density + 0.2))
    shapes = ([0, 2, 1, 2], [0, 1, 2, 1], [0, 2, 3, 2], [0, 0, 2, 1],
              [0, 1, 0, 2], [2, 1, 0, 1])
    shape = rng.choice(shapes)
    return [(onset, duration, shape[index % len(shape)])
            for index, (onset, duration) in enumerate(rhythm)]


def generate_ostinato(spec: MusicSpec, spans: list[tuple[float, float, Chord]],
                      rng: random.Random,
                      figure: list[tuple[float, float, int]] | None = None) -> list[Note]:
    """One figure, restated over every chord. It is the repetition that names it."""
    figure = figure or make_ostinato_figure(spec, rng)
    if not figure:
        return []
    low = 45 + spec.register * 3
    notes: list[Note] = []
    for start, length, chord in spans:
        tones = chord.voice(low=low, high=low + 16)
        if not tones:
            continue
        for onset, duration, index in figure:
            if onset >= length - 1e-6:
                continue
            pitch = tones[index % len(tones)]
            notes.append(_note(spec, rng,
                               apply_swing(start + onset, spec.swing, spec.meter),
                               min(duration, length - onset) * 0.9, pitch, -6))
    return notes


def generate_arpeggio(spec: MusicSpec, spans: list[tuple[float, float, Chord]],
                      rng: random.Random) -> list[Note]:
    """The chord as a running line rather than a block."""
    lifted = spec
    notes: list[Note] = []
    for start, length, chord in spans:
        notes.extend(_arpeggiate(chord, lifted, rng, start, length,
                                 updown=rng.random() < 0.5))
    return notes
