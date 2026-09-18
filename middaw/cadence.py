"""Cadences - how a phrase ends, and how conclusively.

A cadence is a harmonic arrival point; Hutchinson compares it to a comma or a
full stop. Which one a phrase ends with is what makes a period a period: a
less conclusive cadence asks a question, and a more conclusive one answers it.

The five Middaw writes:

| Cadence | Chords | Conclusive? |
| --- | --- | --- |
| Perfect authentic (PAC) | V-I, both root position, 1 in the top voice | most |
| Imperfect authentic (IAC) | V-I, inverted or not topped by the tonic | yes |
| Plagal (PC) | IV-I | yes |
| Deceptive (DC) | V-vi | no |
| Half (HC) | ends on V | no |

Conclusive cadences end on the tonic. That single fact drives the whole of
`middaw.form`: an antecedent section gets an inconclusive cadence, a consequent
gets a conclusive one, and the last section of a piece gets the most conclusive
one there is.
"""

from __future__ import annotations

from dataclasses import dataclass

PAC = "PAC"
IAC = "IAC"
PC = "PC"
DC = "DC"
HC = "HC"


@dataclass(frozen=True)
class CadenceType:
    key: str
    name: str
    conclusive: bool
    #: Scale degrees (0-based indexes into the mode) the phrase ends on.
    degrees: tuple[int, ...]
    #: Whether the approach chord should carry a seventh, sharpening the pull.
    seventh: bool
    #: What the melody should land on: the tonic, or any tone of the chord.
    melody_target: str
    #: Whether the closing chords want root position - a PAC requires it.
    root_position: bool
    description: str


CADENCES: dict[str, CadenceType] = {
    PAC: CadenceType(
        PAC, "perfect authentic", True, (4, 0), True, "tonic", True,
        "V-I with both chords in root position and the tonic on top - the most "
        "conclusive ending there is",
    ),
    IAC: CadenceType(
        IAC, "imperfect authentic", True, (4, 0), False, "chord tone", False,
        "V-I that is inverted or does not put the tonic on top: an ending, but "
        "a softer one",
    ),
    PC: CadenceType(
        PC, "plagal", True, (3, 0), False, "tonic", True,
        "IV-I, the 'amen' cadence - conclusive without the leading-tone pull",
    ),
    DC: CadenceType(
        DC, "deceptive", False, (4, 5), True, "chord tone", False,
        "V-vi: the dominant resolves, but not where the ear expected",
    ),
    HC: CadenceType(
        HC, "half", False, (4,), False, "chord tone", False,
        "the phrase stops on the dominant, leaving the question open",
    ),
}

CONCLUSIVE = tuple(k for k, c in CADENCES.items() if c.conclusive)
INCONCLUSIVE = tuple(k for k, c in CADENCES.items() if not c.conclusive)

#: How final each cadence feels, least to most. A period pairs a lower number
#: with a higher one.
STRENGTH = {HC: 0, DC: 1, IAC: 2, PC: 3, PAC: 4}


def get(kind: str | None) -> CadenceType | None:
    return CADENCES.get(kind or "")


def is_conclusive(kind: str | None) -> bool:
    cadence = get(kind)
    return bool(cadence and cadence.conclusive)


def answers(question: str | None, answer: str | None) -> bool:
    """Is `answer` a more conclusive cadence than `question`?"""
    if question is None or answer is None:
        return False
    return STRENGTH[answer] > STRENGTH[question]
