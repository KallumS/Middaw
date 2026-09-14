"""Sections, so a long generation is a piece rather than a longer loop.

Hutchinson's chapters on phrase and form are the source: popular music breaks
into 4-, 8-, 12- and 16-bar sections; a 32-bar song is usually AABA with eight
bars per section; contrast between sections comes from varying the "elements of
music" - melody, harmony, rhythm, texture, dynamics, register.

So Middaw lays out a form first and renders section by section. A and A'
sections share their harmony and their melodic motif; a B section gets its own
progression and is deliberately pushed away from the A sections in density,
register and dynamics. Without that, thirty-two bars is just eight bars played
four times.
"""

from __future__ import annotations

import random
from dataclasses import dataclass, field

# The lengths a generation may have. Everything snaps to this ladder, because
# these are the lengths real sections come in.
LADDER = (4, 8, 16, 32, 64)

# label, bars-per-section. A trailing apostrophe marks a variation of the
# section before it; the letter is what shares harmony and motif.
LAYOUTS: dict[int, list[tuple[str, int]]] = {
    4: [("A", 4)],
    # A parallel period: one phrase answered by a more conclusive one.
    8: [("A", 4), ("A'", 4)],
    # AABA at four bars a section, the smallest form with a real bridge.
    16: [("A", 4), ("A'", 4), ("B", 4), ("A''", 4)],
    # The 32-bar song form.
    32: [("A", 8), ("A'", 8), ("B", 8), ("A''", 8)],
    # Two turns of the form, the second opened up, with a second contrasting
    # section so the return means something.
    64: [("A", 8), ("A'", 8), ("B", 8), ("A''", 8),
         ("A", 8), ("C", 8), ("B'", 8), ("A''", 8)],
}


def snap_to_ladder(bars: int) -> int:
    """Round a bar count to the nearest length on the ladder."""
    return min(LADDER, key=lambda n: (abs(n - bars), n))


@dataclass
class Section:
    label: str
    bars: int
    start_bar: int
    progression: list[str] = field(default_factory=list)
    progression_labels: list[str] = field(default_factory=list)
    density: float = 0.5
    register: int = 0
    velocity: int = 78
    pattern: str = "block"

    @property
    def letter(self) -> str:
        return self.label.rstrip("'")

    @property
    def variation(self) -> int:
        return self.label.count("'")

    def to_dict(self) -> dict:
        return {"label": self.label, "bars": self.bars, "startBar": self.start_bar + 1,
                "progression": self.progression, "pattern": self.pattern}


def plan_form(spec, rng: random.Random, make_progression=None) -> list[Section]:
    """Lay the piece out as sections and give each one its own character.

    `make_progression(length)` supplies a fresh progression for contrasting
    sections; without it every section shares the spec's harmony.
    """
    layout = LAYOUTS.get(spec.bars)
    if layout is None:
        layout = [("A", spec.bars)]

    # Contrasting sections each get their own harmony, generated once per
    # letter so that B and B' are recognisably the same section.
    harmonies: dict[str, tuple[list[str], list[str]]] = {
        "A": (list(spec.progression), list(spec.progression_labels or spec.progression)),
    }

    sections: list[Section] = []
    start = 0
    for label, bars in layout:
        letter = label.rstrip("'")
        variation = label.count("'")

        if letter not in harmonies:
            if make_progression is not None:
                harmonies[letter] = make_progression(min(bars, 8))
            else:
                harmonies[letter] = harmonies["A"]
        progression, progression_labels = harmonies[letter]

        contrast = letter != "A"
        sections.append(Section(
            label=label,
            bars=bars,
            start_bar=start,
            progression=list(progression),
            progression_labels=list(progression_labels),
            # A bridge lifts: busier, higher, louder. A variation of a section
            # moves a little in the same direction, so A'' is not simply A.
            density=spec.density * (1.2 if contrast else 1.0 + 0.05 * variation),
            register=spec.register + (1 if contrast else 0),
            velocity=spec.velocity + (5 if contrast else 2 * variation),
            pattern=spec.pattern,
        ))
        start += bars
    return sections


def describe(sections: list[Section]) -> str:
    """'A A' B A''' - the form, as a musician would write it."""
    return " ".join(s.label for s in sections)
