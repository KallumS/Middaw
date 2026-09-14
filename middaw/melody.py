"""Motif-based melody generation.

Melodies are built from a short motif that is then varied across the phrase,
rather than sampled note by note. Repetition with variation is what makes a
line sound composed; a first-order Markov walk does not give you that, no
matter how good its statistics are. The corpus supplies the *distributions*
(which intervals, which rhythm cells); this module supplies the *form*.
"""

from __future__ import annotations

import random
from dataclasses import dataclass

from middaw.rhythm import apply_swing, bar_rhythm, pulse_length
from middaw.song import Note
from middaw.spec import MusicSpec
from middaw.theory import Chord, degree_to_pitch, nearest_degree, scale_pitch_classes

# Step sizes in scale degrees, with default weights. Steps dominate; leaps are
# the exception and must be resolved.
DEFAULT_INTERVALS: dict[int, float] = {
    -4: 0.6, -3: 1.2, -2: 2.4, -1: 6.0, 0: 1.4,
    1: 6.4, 2: 2.6, 3: 1.3, 4: 0.7, 5: 0.35, 7: 0.25, -5: 0.3, -7: 0.2,
}


@dataclass
class Motif:
    rhythm: list[tuple[float, float]]
    contour: list[int]


def _weighted_choice(rng: random.Random, weights: dict[int, float]) -> int:
    total = sum(weights.values())
    roll = rng.random() * total
    for value, weight in weights.items():
        roll -= weight
        if roll <= 0:
            return value
    return next(iter(weights))


def _chord_at(chords: list[tuple[float, Chord]], beat: float) -> Chord:
    current = chords[0][1]
    for start, chord in chords:
        if start <= beat + 1e-6:
            current = chord
        else:
            break
    return current


def _make_motif(rng: random.Random, spec: MusicSpec,
                intervals: dict[int, float],
                rhythm_bias: dict[tuple[float, ...], float] | None = None) -> Motif:
    rhythm = bar_rhythm(rng, spec.meter, spec.density, bias=rhythm_bias)
    contour: list[int] = []
    previous = 0
    for _ in range(max(0, len(rhythm) - 1)):
        step = _weighted_choice(rng, intervals)
        if abs(previous) >= 3 and step * previous > 0:
            step = -1 if previous > 0 else 1      # resolve a leap by step back
        contour.append(step)
        previous = step
    return Motif(rhythm=rhythm, contour=contour)


def _vary(rng: random.Random, motif: Motif, spec: MusicSpec,
          intervals: dict[int, float], strength: float,
          rhythm_bias: dict[tuple[float, ...], float] | None = None) -> Motif:
    rhythm = list(motif.rhythm)
    contour = list(motif.contour)
    if rng.random() < strength * 0.5:
        rhythm = bar_rhythm(rng, spec.meter, spec.density, bias=rhythm_bias)
        contour = contour[:max(0, len(rhythm) - 1)]
    while len(contour) < max(0, len(rhythm) - 1):
        contour.append(_weighted_choice(rng, intervals))
    contour = contour[:max(0, len(rhythm) - 1)]
    if contour and rng.random() < strength:
        index = rng.randrange(len(contour))
        contour[index] = _weighted_choice(rng, intervals)
    if contour and rng.random() < strength * 0.35:
        contour = [-step for step in contour]      # inversion
    return Motif(rhythm=rhythm, contour=contour)


def generate_melody(spec: MusicSpec, chords_by_bar: list[list[tuple[float, Chord]]],
                    rng: random.Random,
                    intervals: dict[int, float] | None = None,
                    rhythm_bias: dict[tuple[float, ...], float] | None = None,
                    motif_rng: random.Random | None = None) -> list[Note]:
    """`motif_rng` invents the motif; `rng` varies it and places the notes.

    Passing the same `motif_rng` to two sections makes them the same melody
    differently varied, which is what an A and an A' section are.
    """
    intervals = intervals or DEFAULT_INTERVALS
    motif_rng = motif_rng or rng
    scale = scale_pitch_classes(spec.tonic, spec.mode)
    centre = 60 + spec.register * 3 + 7
    tonic_root = centre - (centre - (spec.tonic + 60)) % 12
    low, high = centre - 10, centre + 16

    beats_per_bar = spec.beats_per_bar
    pulse = pulse_length(spec.meter)
    notes: list[Note] = []

    degree = nearest_degree(scale, tonic_root, centre)
    phrase_length = 4
    motif = _make_motif(motif_rng, spec, intervals, rhythm_bias)
    last_leap = 0

    for bar_index, chords in enumerate(chords_by_bar):
        position_in_phrase = bar_index % phrase_length
        if position_in_phrase == 0:
            if bar_index == 0 or rng.random() < 0.45:
                motif = _make_motif(motif_rng, spec, intervals, rhythm_bias)
            bar_motif = motif
        elif position_in_phrase == 2:
            bar_motif = _vary(rng, motif, spec, intervals, 0.8, rhythm_bias)
        else:
            bar_motif = _vary(rng, motif, spec, intervals, 0.35, rhythm_bias)

        bar_start = bar_index * beats_per_bar
        is_final_bar = bar_index == len(chords_by_bar) - 1
        cadence_bar = is_final_bar or (position_in_phrase == 3)

        for index, (onset, duration) in enumerate(bar_motif.rhythm):
            if index > 0:
                step = bar_motif.contour[min(index - 1, len(bar_motif.contour) - 1)] \
                    if bar_motif.contour else 0
                if abs(last_leap) >= 3 and step * last_leap > 0:
                    step = -1 if last_leap > 0 else 1
                degree += step
                last_leap = step

            pitch = degree_to_pitch(scale, tonic_root, degree)
            if pitch < low:
                degree += len(scale)
                pitch = degree_to_pitch(scale, tonic_root, degree)
            elif pitch > high:
                degree -= len(scale)
                pitch = degree_to_pitch(scale, tonic_root, degree)

            beat = bar_start + onset
            chord = _chord_at(chords, onset)
            on_strong_beat = abs(onset % pulse) < 1e-6
            wants_chord_tone = on_strong_beat or duration >= pulse
            if wants_chord_tone and pitch % 12 not in chord.pitch_classes:
                pitch = chord.nearest_tone(pitch)
                degree = nearest_degree(scale, tonic_root, pitch)

            if cadence_bar and index == len(bar_motif.rhythm) - 1:
                target = chord.nearest_tone(pitch)
                if is_final_bar:
                    target = pitch + ((spec.tonic - pitch) % 12)
                    if target - pitch > 6:
                        target -= 12
                pitch = target
                degree = nearest_degree(scale, tonic_root, pitch)
                duration = max(duration, pulse)

            velocity = spec.velocity + (6 if on_strong_beat else -4)
            velocity += int(rng.gauss(0, 4) * spec.humanize)
            notes.append(Note(
                start=apply_swing(beat - bar_start, spec.swing, spec.meter) + bar_start,
                duration=max(0.1, duration * rng.uniform(0.82, 0.98)),
                pitch=max(21, min(108, pitch)),
                velocity=max(1, min(127, velocity)),
            ))

    return notes
