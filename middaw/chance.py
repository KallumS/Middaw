"""The named dice.

The generator was always random — but its probabilities were scattered through
the code as bare numbers: `rng.random() < 0.45` here, `< 0.7` there. A number
like that cannot be read, cannot be changed by a style, and cannot be checked
against real music. This module gives every one of them a name, a home and a
default that came from a measurement where we have one.

A `Chances` is part of the spec, so it is part of what a prompt resolves to and
part of what a genre can set. `docs/MEASUREMENTS.md` has the real-music figures
each default is drawn from; `docs/APPROACH.md` says why the generator is a
parameter vector and a procedure rather than a model.

Two rules for anything added here:

- **A probability is a fact about a style, not a knob to taste.** Where a
  corpus can answer it, the default is what the corpus said, and the comment
  says which corpus.
- **Whatever it claims, it has to do.** `tests/test_chance.py` rolls each one a
  few thousand times and checks the rate that comes out is the rate asked for.
"""

from __future__ import annotations

import random
from dataclasses import asdict, dataclass, fields

#: How far a melody moves, as a class rather than a size. A step is a second,
#: a skip is a third, a leap is a fourth or more, and the sizes inside each
#: class still come from the interval distribution (`middaw/melody.py`), which
#: is what a corpus supplies.
MOVES = ("repeat", "step", "skip", "leap")

#: Which note of the chord the bass takes. The bass is monophonic, always.
BASS_TONES = ("root", "fifth", "third")


@dataclass
class Chances:
    """Every probability the generator rolls, in one place.

    Melodic defaults are the middle of the measured range: a chorale melody
    steps 70% of the time and a nineteenth-century song 47%, so a style that
    has not been measured starts between them rather than at either end.
    """

    # --- melody ---------------------------------------------------------
    step: float = 0.55           # next note is a second away
    skip: float = 0.20           # ...a third
    repeat: float = 0.15         # ...the same note again
    #: Anything left over is a leap of a fourth or more.
    leap_turns_back: float = 0.90
    """After a leap, move back the other way.

    Rule 2 of the melodic rules in `docs/THEORY.md`. Real music does this
    77-92% of the time depending on repertoire; Middaw used to do it 77%,
    which was the bottom of the range.
    """

    # --- harmony and cadence --------------------------------------------
    cadence_lands_home: float = 0.80
    """The last section actually closes on the tonic.

    The rest of the time it ends somewhere else in the key, which is what a
    piece that fades rather than finishes does.
    """
    cadence_deceptive: float = 0.30      # a deceptive turn just before the end
    twin_answers: float = 0.70           # A asks and A' answers, not A A again

    # --- melody form -----------------------------------------------------
    new_motif: float = 0.45              # start a phrase with a fresh motif

    # --- bass -------------------------------------------------------------
    bass_root: float = 0.70              # the bass takes the chord's root
    bass_fifth: float = 0.20             # ...or its fifth
    #: Anything left over is the third, which is what makes a first inversion.

    # ------------------------------------------------------------------
    @property
    def leap(self) -> float:
        return max(0.0, 1.0 - self.step - self.skip - self.repeat)

    @property
    def bass_third(self) -> float:
        return max(0.0, 1.0 - self.bass_root - self.bass_fifth)

    def move(self, rng: random.Random) -> str:
        """How far the melody goes next: repeat, step, skip or leap."""
        return _pick(rng, {"repeat": self.repeat, "step": self.step,
                           "skip": self.skip, "leap": self.leap})

    def bass_tone(self, rng: random.Random) -> str:
        """Which note of the chord the bass plays."""
        return _pick(rng, {"root": self.bass_root, "fifth": self.bass_fifth,
                           "third": self.bass_third})

    def to_dict(self) -> dict:
        return {name: round(value, 4) for name, value in asdict(self).items()}

    def replace(self, **changes) -> "Chances":
        values = asdict(self)
        values.update({k: v for k, v in changes.items() if k in values})
        return Chances(**values).clamp()

    def clamp(self) -> "Chances":
        for field in fields(self):
            setattr(self, field.name,
                    max(0.0, min(1.0, float(getattr(self, field.name)))))
        # The three melodic classes share one budget; the leftover is the leap.
        total = self.step + self.skip + self.repeat
        if total > 1.0:
            self.step /= total
            self.skip /= total
            self.repeat /= total
        if self.bass_root + self.bass_fifth > 1.0:
            share = self.bass_root + self.bass_fifth
            self.bass_root /= share
            self.bass_fifth /= share
        return self


def _pick(rng: random.Random, options: dict[str, float]) -> str:
    """Choose one name, weighted. Falls back to the first if every weight is 0."""
    total = sum(max(0.0, weight) for weight in options.values())
    if total <= 0:
        return next(iter(options))
    roll = rng.random() * total
    for name, weight in options.items():
        roll -= max(0.0, weight)
        if roll <= 0:
            return name
    return next(reversed(options))


FIELD_NAMES = tuple(field.name for field in fields(Chances))


def from_entry(entry: dict, base: Chances | None = None) -> Chances:
    """Read a `chances` block out of a vocabulary entry, over the defaults."""
    chances = base or Chances()
    return chances.replace(**{k: v for k, v in (entry.get("chances") or {}).items()
                              if k in FIELD_NAMES})
