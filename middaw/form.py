"""Form - how a piece is laid out, and how each section ends.

A generation longer than a phrase is a *form*, not a longer loop. Middaw picks
one, gives every section a length and a character, and gives every section a
**cadence**, because how a section ends is what makes the next one feel like an
answer rather than a restart.

The catalogue covers the forms in common use:

| Form | Shape | Where it comes from |
| --- | --- | --- |
| motif | A | a single statement |
| period | A A' | question and answer |
| strophic | A A' A'' | folk song, blues, hymn |
| binary | A B | Baroque dance movements |
| binary repeated | A A' B B' | the same with both strains repeated |
| ternary | A B A' | statement, contrast, return |
| AABA | A A' B A'' | the 32-bar song |
| rondo | A B A' C A'' | the refrain keeps coming back |
| rondo (seven-part) | A B A' C A'' B' A''' | |
| medley | A B C D | one tune after another |
| through-composed | A B C D E | nothing returns |
| sonata | A B Dev A' B' | exposition, development, recapitulation |
| fugue | subject, answer, episode, entries, stretto | |

Sections sharing a letter share their harmony and their melodic motif, so a
return is heard as a return. Contrasting sections get their own progression and
are pushed away in density, register and dynamics - Hutchinson's "elements of
music" are what contrast is made of.
"""

from __future__ import annotations

import random
from dataclasses import dataclass, field

from middaw.cadence import DC, HC, IAC, PAC, PC

# Lengths a section may have. Everything lands on these because these are the
# lengths sections actually come in.
SECTION_LENGTHS = (4, 8, 16)
LADDER = (4, 8, 16, 32, 64)
MAX_BARS = 128

# (label, role). The label carries identity - sections sharing a letter share
# harmony and motif - while the role says what the section is doing.
FORMS: dict[str, list[tuple[str, str]]] = {
    "motif": [("A", "statement")],
    "period": [("A", "antecedent"), ("A'", "consequent")],
    "strophic": [("A", "verse"), ("A'", "verse"), ("A''", "verse")],
    "binary": [("A", "first strain"), ("B", "second strain")],
    "binary_repeated": [("A", "first strain"), ("A'", "first strain repeated"),
                        ("B", "second strain"), ("B'", "second strain repeated")],
    "ternary": [("A", "statement"), ("B", "contrast"), ("A'", "return")],
    "aaba": [("A", "verse"), ("A'", "verse"), ("B", "bridge"), ("A''", "verse")],
    "rondo": [("A", "refrain"), ("B", "first episode"), ("A'", "refrain"),
              ("C", "second episode"), ("A''", "refrain")],
    "rondo_seven": [("A", "refrain"), ("B", "first episode"), ("A'", "refrain"),
                    ("C", "second episode"), ("A''", "refrain"),
                    ("B'", "first episode returns"), ("A'''", "refrain")],
    "medley": [("A", "first tune"), ("B", "second tune"), ("C", "third tune"),
               ("D", "fourth tune")],
    "through_composed": [("A", "first idea"), ("B", "second idea"),
                         ("C", "third idea"), ("D", "fourth idea"),
                         ("E", "closing idea")],
    "sonata": [("A", "first subject"), ("B", "second subject"),
               ("C", "development"), ("A'", "recapitulation"),
               ("B'", "second subject in the tonic")],
    "fugue": [("A", "subject"), ("A'", "answer"), ("B", "episode"),
              ("A''", "middle entry"), ("B'", "episode"), ("A'''", "final entry")],
}

#: Sections whose job is to lead somewhere else, so they end on the dominant.
OPEN_ROLES = ("antecedent", "bridge", "episode", "development", "contrast",
              "first strain", "second subject")

#: What each style tends to be built as.
GENRE_FORMS: dict[str, tuple[str, ...]] = {
    "baroque": ("binary", "binary_repeated", "fugue", "ternary"),
    "classical": ("ternary", "rondo", "sonata", "period"),
    "romantic_era": ("ternary", "rondo", "through_composed"),
    "folk": ("strophic", "binary", "period"),
    "celtic": ("binary_repeated", "binary", "strophic"),
    "blues": ("strophic",),
    "jazz": ("aaba", "rondo"),
    "ragtime": ("rondo", "medley"),
    "gospel": ("strophic", "aaba"),
    "pop": ("aaba", "strophic"),
    "rnb": ("aaba",),
    "lofi": ("strophic", "aaba"),
    "ballad": ("aaba", "ternary"),
    "ambient": ("through_composed", "strophic"),
    "minimal": ("strophic", "through_composed"),
    "cinematic": ("ternary", "through_composed", "rondo"),
    "house": ("strophic", "binary"),
    "techno": ("strophic",),
    "trap": ("aaba", "strophic"),
    "chiptune": ("binary_repeated", "ternary"),
    "rock": ("aaba", "strophic"),
    "waltz": ("ternary", "rondo"),
    "tango": ("binary", "ternary"),
    "bossa": ("aaba",),
    "minimal_techno": ("strophic",),
}

#: Styles that lean on the plagal "amen" ending.
PLAGAL_GENRES = {"gospel", "folk", "celtic", "ambient", "gospel"}


def snap_to_ladder(bars: int) -> int:
    """Round a bar count to the nearest length on the ladder."""
    return min(LADDER, key=lambda n: (abs(n - bars), n))


@dataclass
class Section:
    label: str
    bars: int
    start_bar: int
    role: str = ""
    cadence: str = PAC
    transpose: int = 0
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
                "role": self.role, "cadence": self.cadence,
                "progression": self.progression, "pattern": self.pattern}


def choose_form(spec, rng: random.Random) -> str:
    """Pick a form: what the prompt asked for, else what the style is built as."""
    if getattr(spec, "forms", None):
        for name in spec.forms:
            if name in FORMS:
                return name

    target = spec.bars
    if target <= 4:
        return "motif"
    if target <= 8:
        return "period"

    pool: list[str] = []
    for genre in getattr(spec, "genres", []):
        pool.extend(GENRE_FORMS.get(genre, ()))
    if not pool:
        # Something called a symphony or a suite wants a form with somewhere to
        # go; anything shorter and unnamed falls back to the song forms.
        pool = (["sonata", "rondo", "rondo_seven", "through_composed", "medley"]
                if target >= 48 else ["aaba", "ternary", "strophic", "binary"])

    if target >= 48:
        richer = [name for name in pool if len(FORMS[name]) >= 4]
        pool = richer or pool
    return rng.choice(pool)


def _section_length(count: int, target: int) -> int:
    """How long each section should be to land nearest the requested length."""
    best = min(SECTION_LENGTHS,
               key=lambda n: (abs(count * n - target), n))
    while count * best > MAX_BARS and best > SECTION_LENGTHS[0]:
        best = SECTION_LENGTHS[SECTION_LENGTHS.index(best) - 1]
    return best


def plan_cadences(layout: list[tuple[str, str]], rng: random.Random,
                  plagal_bias: float = 0.0) -> list[str]:
    """Give every section an ending, so the piece asks and answers.

    The last section gets the most conclusive cadence there is. Sections whose
    job is to lead somewhere - an antecedent, a bridge, an episode, a
    development - stop on the dominant. Everything else alternates question and
    answer, with the occasional deceptive turn just before the end.
    """
    plan: list[str] = []
    total = len(layout)
    for index, (label, role) in enumerate(layout):
        letter = label.rstrip("'")
        next_letter = (layout[index + 1][0].rstrip("'")
                       if index + 1 < total else None)

        if index == total - 1:
            plan.append(PC if rng.random() < plagal_bias else PAC)
        elif any(open_role in role for open_role in OPEN_ROLES):
            # Its job is to lead somewhere, so it stops on the dominant.
            plan.append(HC)
        elif next_letter == letter and rng.random() < 0.7:
            # The first of a pair is an antecedent: it asks, and its twin
            # answers. That is what makes A A' a period rather than a repeat.
            plan.append(HC)
        elif index == total - 2 and rng.random() < 0.30:
            # A deceptive cadence just before the end makes the final
            # resolution land harder.
            plan.append(DC)
        else:
            plan.append(IAC)
    return plan


def plan_form(spec, rng: random.Random, make_progression=None) -> list[Section]:
    """Lay the piece out: form, section lengths, cadences and character.

    `make_progression(length, cadence)` supplies harmony for a section; without
    it every section shares the spec's progression.
    """
    form = choose_form(spec, rng)
    layout = FORMS[form]

    # An explicit bar count that is not a plain multiple of the form is taken
    # at its word: it becomes one section.
    bars = _section_length(len(layout), spec.bars)
    if len(layout) * bars != spec.bars and spec.bars not in LADDER:
        layout = [("A", "statement")]
        bars = spec.bars

    plagal = 0.35 if set(getattr(spec, "genres", [])) & PLAGAL_GENRES else 0.06
    cadence_plan = plan_cadences(layout, rng, plagal)

    # One progression per letter, re-ended for each cadence that letter takes.
    bases: dict[str, tuple[list[str], list[str]]] = {}
    harmonies: dict[tuple[str, str], tuple[list[str], list[str]]] = {}
    sections: list[Section] = []
    start = 0
    for (label, role), cadence in zip(layout, cadence_plan):
        letter = label.rstrip("'")
        variation = label.count("'")

        # Harmony is shared by letter *and* ending: a refrain that stops on the
        # dominant and one that closes are the same section, differently ended.
        key = (letter, cadence)
        if key not in harmonies:
            if letter not in bases:
                if make_progression is not None:
                    bases[letter] = make_progression(min(bars, 8), cadence)
                elif letter == "A" or not bases:
                    bases[letter] = (list(spec.progression),
                                     list(spec.progression_labels or spec.progression))
                else:
                    bases[letter] = bases[next(iter(bases))]
                harmonies[key] = bases[letter]
            elif make_progression is not None:
                harmonies[key] = make_progression(min(bars, 8), cadence,
                                                  bases[letter])
            else:
                harmonies[key] = bases[letter]
        progression, progression_labels = harmonies[key]

        # In a fugue the answer enters a fifth above the subject. That
        # relationship is what makes it a fugue rather than a repeat.
        transpose = 7 if (form == "fugue" and "answer" in role) else 0

        contrast = letter != "A"
        sections.append(Section(
            label=label,
            bars=bars,
            start_bar=start,
            role=role,
            cadence=cadence,
            transpose=transpose,
            progression=list(progression),
            progression_labels=list(progression_labels),
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


def describe_cadences(sections: list[Section]) -> str:
    return " ".join(f"{s.label}:{s.cadence}" for s in sections)
