"""Accompaniment and bass figures.

Each pattern is a small function that fills one chord span. Adding a style
means adding a function here and a weight in `data/vocab/tags.json`.
"""

from __future__ import annotations

import random

from middaw.rhythm import apply_swing, is_compound, pulse_length
from middaw.song import Note
from middaw.spec import MusicSpec
from middaw.theory import Chord


def _voiced(chord: Chord, spec: MusicSpec) -> list[int]:
    low = 48 + spec.register * 3
    return chord.voice(low=low, high=low + 22)


def _note(spec: MusicSpec, rng: random.Random, start: float, duration: float,
          pitch: int, velocity_offset: int = 0) -> Note:
    velocity = spec.velocity + velocity_offset + int(rng.gauss(0, 3) * spec.humanize)
    return Note(
        start=start,
        duration=max(0.08, duration),
        pitch=max(21, min(108, pitch)),
        velocity=max(1, min(127, velocity)),
    )


def pattern_block(chord, spec, rng, start, length):
    pulse = pulse_length(spec.meter)
    hits = max(1, int(round(length / (pulse * (1 if spec.density > 0.55 else 2)))))
    step = length / hits
    notes = []
    for i in range(hits):
        for pitch in _voiced(chord, spec):
            notes.append(_note(spec, rng, start + i * step, step * 0.92, pitch,
                               -8 if i else 0))
    return notes


def pattern_sustained(chord, spec, rng, start, length):
    return [_note(spec, rng, start, length * 0.99, pitch, -14)
            for pitch in _voiced(chord, spec)]


def pattern_rolled(chord, spec, rng, start, length):
    notes = []
    spread = 0.045
    for i, pitch in enumerate(_voiced(chord, spec)):
        notes.append(_note(spec, rng, start + i * spread, length - i * spread, pitch, -10))
    return notes


def _arp_sequence(chord, spec, updown: bool) -> list[int]:
    tones = _voiced(chord, spec)
    tones = tones + [tones[0] + 12]
    if updown and len(tones) > 2:
        return tones + tones[-2:0:-1]
    return tones


def pattern_arpeggio_up(chord, spec, rng, start, length):
    return _arpeggiate(chord, spec, rng, start, length, updown=False)


def pattern_arpeggio_updown(chord, spec, rng, start, length):
    return _arpeggiate(chord, spec, rng, start, length, updown=True)


def _arpeggiate(chord, spec, rng, start, length, updown: bool):
    sequence = _arp_sequence(chord, spec, updown)
    step = 0.25 if spec.density > 0.7 else 0.5
    if is_compound(spec.meter):
        step = 0.5
    count = max(1, int(round(length / step)))
    notes = []
    for i in range(count):
        pitch = sequence[i % len(sequence)]
        onset = start + i * step
        notes.append(_note(spec, rng, apply_swing(onset, spec.swing, spec.meter),
                           step * 0.95, pitch, -6 if i % 2 else 0))
    return notes


def pattern_alberti(chord, spec, rng, start, length):
    tones = _voiced(chord, spec)
    while len(tones) < 3:
        tones.append(tones[0] + 12)
    order = [tones[0], tones[2], tones[1], tones[2]]
    step = 0.25 if spec.density > 0.65 else 0.5
    count = max(1, int(round(length / step)))
    return [_note(spec, rng, start + i * step, step * 0.95, order[i % 4], -6 if i % 2 else 0)
            for i in range(count)]


def pattern_waltz(chord, spec, rng, start, length):
    tones = _voiced(chord, spec)
    notes = [_note(spec, rng, start, 0.9, tones[0] - 12, 4)]
    upper = tones[1:] or tones
    for beat in (1.0, 2.0):
        if beat < length:
            for pitch in upper:
                notes.append(_note(spec, rng, start + beat, 0.85, pitch, -10))
    return notes


def pattern_offbeat(chord, spec, rng, start, length):
    tones = _voiced(chord, spec)
    step = 0.5
    notes = []
    position = 0.5
    while position < length - 1e-6:
        for pitch in tones:
            notes.append(_note(spec, rng,
                               apply_swing(start + position, spec.swing, spec.meter),
                               step * 0.8, pitch, -6))
        position += 1.0
    if not notes:
        return pattern_block(chord, spec, rng, start, length)
    return notes


def pattern_broken_octave(chord, spec, rng, start, length):
    tones = _voiced(chord, spec)
    root = tones[0] - 12
    notes = []
    position = 0.0
    index = 0
    while position < length - 1e-6:
        if index % 2 == 0:
            notes.append(_note(spec, rng, start + position, 0.9, root, 2))
            notes.append(_note(spec, rng, start + position, 0.9, root + 12, -4))
        else:
            for pitch in tones[1:] or tones:
                notes.append(_note(spec, rng, start + position, 0.8, pitch, -10))
        position += 1.0
        index += 1
    return notes


def pattern_ballad(chord, spec, rng, start, length):
    tones = _voiced(chord, spec)
    notes = [_note(spec, rng, start + i * 0.03, length * 0.98, pitch, -12)
             for i, pitch in enumerate(tones)]
    mid = length / 2
    if mid >= 1.0 and tones:
        notes.append(_note(spec, rng, start + mid, length / 2, tones[-1] + 12, -18))
    return notes


def pattern_walking(chord, spec, rng, start, length):
    tones = _voiced(chord, spec)
    notes = []
    position = 0.0
    index = 0
    while position < length - 1e-6:
        pitch = tones[index % len(tones)]
        notes.append(_note(spec, rng, start + position, 0.95, pitch, -6))
        position += 1.0
        index += 1
    return notes


def pattern_ostinato(chord, spec, rng, start, length):
    tones = _voiced(chord, spec)
    figure = [0, 1, 0, 2] if len(tones) > 2 else [0, 1, 0, 1]
    step = 0.25 if spec.density > 0.7 else 0.5
    count = max(1, int(round(length / step)))
    return [_note(spec, rng, apply_swing(start + i * step, spec.swing, spec.meter),
                  step * 0.9, tones[figure[i % len(figure)] % len(tones)],
                  -4 if i % 2 else 2)
            for i in range(count)]


PATTERNS = {
    "block": pattern_block,
    "sustained": pattern_sustained,
    "rolled": pattern_rolled,
    "arpeggio_up": pattern_arpeggio_up,
    "arpeggio_updown": pattern_arpeggio_updown,
    "alberti": pattern_alberti,
    "waltz": pattern_waltz,
    "offbeat": pattern_offbeat,
    "broken_octave": pattern_broken_octave,
    "ballad": pattern_ballad,
    "walking": pattern_walking,
    "ostinato": pattern_ostinato,
}


def generate_accompaniment(spec: MusicSpec, spans: list[tuple[float, float, Chord]],
                           rng: random.Random) -> list[Note]:
    handler = PATTERNS.get(spec.pattern, pattern_block)
    notes: list[Note] = []
    for start, length, chord in spans:
        notes.extend(handler(chord, spec, rng, start, length))
    return notes


def generate_bass(spec: MusicSpec, spans: list[tuple[float, float, Chord]],
                  rng: random.Random) -> list[Note]:
    """Root-driven bass; walks when the style already implies a walking feel."""
    root_octave = 36 + spec.register * 3
    walking = spec.pattern in ("walking", "offbeat") and spec.density > 0.5
    notes: list[Note] = []
    for start, length, chord in spans:
        root = root_octave + ((chord.root - root_octave) % 12)
        if spec.pattern == "waltz":
            notes.append(_note(spec, rng, start, length * 0.9, root, 6))
            continue
        if walking:
            tones = [root, root + 7, root + 12, root + 5]
            position = 0.0
            index = 0
            while position < length - 1e-6:
                notes.append(_note(spec, rng, start + position, 0.9,
                                   tones[index % len(tones)], 4 if index == 0 else -4))
                position += 1.0
                index += 1
        else:
            notes.append(_note(spec, rng, start, min(length, length * 0.95), root, 6))
            if length >= 2.0 and spec.density > 0.45:
                notes.append(_note(spec, rng, start + length / 2, length / 2 * 0.9,
                                   root + 7, -6))
    return notes
