"""Rhythm-cell vocabulary.

A "cell" is one pulse worth of durations, written as fractions of that pulse.
Negative values are rests. Building bars from cells (rather than from a flat
random grid) is what keeps generated rhythm idiomatic instead of noisy, and it
gives the corpus something concrete to learn: cell frequencies per tag.
"""

from __future__ import annotations

import random

# (durations, density_low, density_high, weight)
SIMPLE_CELLS: list[tuple[tuple[float, ...], float, float, float]] = [
    ((2.0,),                        0.00, 0.45, 3.0),
    ((1.5, 0.5),                    0.15, 0.65, 2.0),
    ((1.0,),                        0.00, 0.75, 4.0),
    ((-1.0,),                       0.00, 0.50, 2.0),
    ((0.5, 0.5),                    0.25, 1.00, 4.0),
    ((-0.5, 0.5),                   0.30, 1.00, 2.0),
    ((0.5, -0.5),                   0.20, 0.85, 1.5),
    ((0.75, 0.25),                  0.35, 1.00, 2.0),
    ((0.25, 0.75),                  0.40, 1.00, 1.5),
    ((0.5, 0.25, 0.25),             0.50, 1.00, 2.5),
    ((0.25, 0.25, 0.5),             0.50, 1.00, 2.5),
    ((0.25, 0.25, 0.25, 0.25),      0.65, 1.00, 3.0),
    ((1 / 3, 1 / 3, 1 / 3),         0.45, 1.00, 1.5),
]

COMPOUND_CELLS: list[tuple[tuple[float, ...], float, float, float]] = [
    ((2.0,),                        0.00, 0.35, 2.0),
    ((1.0,),                        0.00, 0.55, 3.0),
    ((-1.0,),                       0.00, 0.40, 1.5),
    ((2 / 3, 1 / 3),                0.25, 1.00, 3.0),
    ((1 / 3, 1 / 3, 1 / 3),         0.35, 1.00, 4.0),
    ((1 / 3, -1 / 3, 1 / 3),        0.40, 1.00, 1.5),
    ((1 / 3, 2 / 3),                0.30, 1.00, 2.0),
    ((1 / 6, 1 / 6, 1 / 3, 1 / 3),  0.70, 1.00, 2.0),
    ((1 / 6,) * 6,                  0.80, 1.00, 1.5),
]


def is_compound(meter: tuple[int, int]) -> bool:
    num, den = meter
    return den == 8 and num % 3 == 0 and num > 3


def pulse_length(meter: tuple[int, int]) -> float:
    """Length of one felt pulse, in quarter notes."""
    return 1.5 if is_compound(meter) else (4.0 / meter[1])


def pulses_per_bar(meter: tuple[int, int]) -> int:
    num, den = meter
    return num // 3 if is_compound(meter) else num


def _cell_weight(cell, density: float) -> float:
    durations, low, high, weight = cell
    if not (low <= density <= high):
        return 0.0
    # Peak weight in the middle of the cell's comfortable density band.
    centre = (low + high) / 2
    span = max(0.2, (high - low) / 2)
    closeness = max(0.15, 1.0 - abs(density - centre) / span)
    return weight * closeness


def choose_cell(rng: random.Random, density: float, compound: bool,
                bias: dict[tuple[float, ...], float] | None = None) -> tuple[float, ...]:
    cells = COMPOUND_CELLS if compound else SIMPLE_CELLS
    weighted = []
    for cell in cells:
        weight = _cell_weight(cell, density)
        if bias:
            weight *= 1.0 + bias.get(cell[0], 0.0)
        if weight > 0:
            weighted.append((cell[0], weight))
    if not weighted:
        return (1.0,)
    total = sum(w for _, w in weighted)
    roll = rng.random() * total
    for durations, weight in weighted:
        roll -= weight
        if roll <= 0:
            return durations
    return weighted[-1][0]


def bar_rhythm(rng: random.Random, meter: tuple[int, int], density: float,
               bias: dict[tuple[float, ...], float] | None = None,
               start_on_downbeat: bool = True) -> list[tuple[float, float]]:
    """Return [(onset_in_beats, duration_in_beats)] for one bar."""
    compound = is_compound(meter)
    pulse = pulse_length(meter)
    total_pulses = pulses_per_bar(meter)
    onsets: list[tuple[float, float]] = []

    position = 0.0
    remaining = float(total_pulses)
    while remaining > 1e-6:
        cell = choose_cell(rng, density, compound, bias)
        if sum(abs(d) for d in cell) > remaining + 1e-6:
            cell = (min(1.0, remaining),)
        for value in cell:
            length = abs(value) * pulse
            if value > 0:
                onsets.append((position, length))
            position += length
        remaining -= sum(abs(d) for d in cell)

    if start_on_downbeat and (not onsets or onsets[0][0] > 1e-6):
        onsets.insert(0, (0.0, pulse))
        onsets = _dedupe(onsets)
    return onsets


def _dedupe(onsets: list[tuple[float, float]]) -> list[tuple[float, float]]:
    out: list[tuple[float, float]] = []
    for onset, duration in sorted(onsets):
        if out and onset - out[-1][0] < 1e-6:
            continue
        if out:
            prev_onset, prev_duration = out[-1]
            out[-1] = (prev_onset, min(prev_duration, onset - prev_onset))
        out.append((onset, duration))
    return [(o, d) for o, d in out if d > 1e-6]


def apply_swing(onset: float, swing: float, meter: tuple[int, int]) -> float:
    """Push offbeat eighths later. `swing` 0 = straight, 1/3 = triplet feel."""
    if swing <= 1e-6 or is_compound(meter):
        return onset
    position = onset % 1.0
    if abs(position - 0.5) < 1e-6:
        return onset + swing * 0.5
    return onset
