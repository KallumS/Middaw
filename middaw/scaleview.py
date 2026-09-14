"""Scales, key-aware spelling and chord reading.

Ported from ScaleView Pro (github.com/KallumS/scaleview-for-reaper, MIT), the
same author's REAPER script, so Middaw and ScaleView agree on what a scale is
and on what a set of notes is called. Two things come across:

* **Spelling.** A scale carries a *letter* for each degree as well as a
  semitone interval, which is what makes Gb major read Gb Ab Bb Cb Db Eb F
  instead of F# G# A# B C# D# F. Middaw needs this for key signatures in the
  MIDI it writes and for anything it shows the user.
* **The chord reader.** `detect_chord` works out what a set of pitch classes
  is called by *reading* the intervals rather than matching a table of shapes.
  ScaleView measures it at 99.999% of 363,963 sonorities in the music21 core
  corpus and 100% of all 17,688 three-to-seven-note voicings; a lookup table
  scored 93.3% and 23.9% on the same tests. That accuracy is what makes it
  usable for corpus labelling, where every chord symbol in the dataset is
  derived by this function and never typed by hand.

The ranking constants and their reasoning are ScaleView's; see that repo's
CLAUDE.md for the measurements behind each one. Keep the two in step: a fix
here probably belongs there too.
"""

from __future__ import annotations

from dataclasses import dataclass

SHARP_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
FLAT_NAMES = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

LETTERS = ["C", "D", "E", "F", "G", "A", "B"]
LETTER_PCS = [0, 2, 4, 5, 7, 9, 11]
ACCIDENTALS = {-2: "bb", -1: "b", 0: "", 1: "#", 2: "x"}


@dataclass(frozen=True)
class Root:
    name: str
    letter: int      # index into LETTERS
    acc: int

    @property
    def pitch_class(self) -> int:
        return (LETTER_PCS[self.letter] + self.acc) % 12


# Both spellings of every pitch class, plus Cb: C# major and Db major are the
# same seven notes spelled differently, so each needs its own entry.
ROOTS = [
    Root("C", 0, 0), Root("C#", 0, 1), Root("Db", 1, -1), Root("D", 1, 0),
    Root("D#", 1, 1), Root("Eb", 2, -1), Root("E", 2, 0), Root("F", 3, 0),
    Root("F#", 3, 1), Root("Gb", 4, -1), Root("G", 4, 0), Root("G#", 4, 1),
    Root("Ab", 5, -1), Root("A", 5, 0), Root("A#", 5, 1), Root("Bb", 6, -1),
    Root("B", 6, 0), Root("Cb", 0, -1),
]

ROOTS_BY_NAME = {r.name: r for r in ROOTS}
CHORD_ROOT_NAMES = {r.name for r in ROOTS}


@dataclass(frozen=True)
class Scale:
    """`intervals` are semitones from the root; `letters` are how many letter
    names each degree sits above the root letter, which is what makes the
    spelling come out right."""

    name: str
    intervals: tuple[int, ...]
    letters: tuple[int, ...]


# ScaleView's sixteen, plus melodic minor and locrian, which Middaw generates
# in but ScaleView does not offer.
SCALES: dict[str, Scale] = {
    "major": Scale("Major", (0, 2, 4, 5, 7, 9, 11), (0, 1, 2, 3, 4, 5, 6)),
    "minor": Scale("Minor (Natural)", (0, 2, 3, 5, 7, 8, 10), (0, 1, 2, 3, 4, 5, 6)),
    "harmonic_minor": Scale("Harmonic Minor", (0, 2, 3, 5, 7, 8, 11), (0, 1, 2, 3, 4, 5, 6)),
    "melodic_minor": Scale("Melodic Minor", (0, 2, 3, 5, 7, 9, 11), (0, 1, 2, 3, 4, 5, 6)),
    "ionian": Scale("Ionian", (0, 2, 4, 5, 7, 9, 11), (0, 1, 2, 3, 4, 5, 6)),
    "dorian": Scale("Dorian", (0, 2, 3, 5, 7, 9, 10), (0, 1, 2, 3, 4, 5, 6)),
    "phrygian": Scale("Phrygian", (0, 1, 3, 5, 7, 8, 10), (0, 1, 2, 3, 4, 5, 6)),
    "lydian": Scale("Lydian", (0, 2, 4, 6, 7, 9, 11), (0, 1, 2, 3, 4, 5, 6)),
    "mixolydian": Scale("Mixolydian", (0, 2, 4, 5, 7, 9, 10), (0, 1, 2, 3, 4, 5, 6)),
    "aeolian": Scale("Aeolian", (0, 2, 3, 5, 7, 8, 10), (0, 1, 2, 3, 4, 5, 6)),
    "locrian": Scale("Locrian", (0, 1, 3, 5, 6, 8, 10), (0, 1, 2, 3, 4, 5, 6)),
    "major_pentatonic": Scale("Major Pentatonic", (0, 2, 4, 7, 9), (0, 1, 2, 4, 5)),
    "minor_pentatonic": Scale("Minor Pentatonic", (0, 3, 5, 7, 10), (0, 2, 3, 4, 6)),
    "major_blues": Scale("Major Blues", (0, 2, 3, 4, 7, 9), (0, 1, 2, 2, 4, 5)),
    "blues": Scale("Minor Blues", (0, 3, 5, 6, 7, 10), (0, 2, 3, 4, 4, 6)),
    "whole_tone": Scale("Whole Tone", (0, 2, 4, 6, 8, 10), (0, 1, 2, 3, 4, 5)),
    "diminished_wh": Scale("Diminished Whole-Half", (0, 2, 3, 5, 6, 8, 9, 11),
                           (0, 1, 2, 3, 4, 5, 5, 6)),
    "diminished_hw": Scale("Diminished Half-Whole", (0, 1, 3, 4, 6, 7, 9, 10),
                           (0, 1, 2, 2, 3, 4, 5, 6)),
}


def spell_as(letter: int, pitch_class: int) -> str | None:
    """Name `pitch_class` using the given letter, or None if it needs a triple."""
    letter %= 7
    offset = ((pitch_class - LETTER_PCS[letter] + 6) % 12) - 6   # -6..+5
    accidental = ACCIDENTALS.get(offset)
    if accidental is None:
        return None
    return LETTERS[letter] + accidental


class Key:
    """A root plus a scale: which pitch classes are in it, and how to spell them."""

    def __init__(self, root: str | Root = "C", scale: str = "major"):
        self.root = ROOTS_BY_NAME[root] if isinstance(root, str) else root
        self.scale_id = scale if scale in SCALES else "major"
        self.scale = SCALES[self.scale_id]
        self.tonic = self.root.pitch_class

        self.names: dict[int, str] = {}
        self.active: set[int] = set()
        sharps = flats = 0
        for degree, interval in enumerate(self.scale.intervals):
            pitch_class = (self.tonic + interval) % 12
            name = spell_as(self.root.letter + self.scale.letters[degree], pitch_class)
            self.active.add(pitch_class)
            if name:
                self.names[pitch_class] = name
                if "#" in name or "x" in name:
                    sharps += 1
                if "b" in name[1:]:          # skip the note letter B
                    flats += 1

        # Notes outside the scale have no spelling of their own, so name them
        # in whichever direction the key leans.
        self.uses_flats = flats > sharps
        outside = FLAT_NAMES if self.uses_flats else SHARP_NAMES
        for pitch_class in range(12):
            self.names.setdefault(pitch_class, outside[pitch_class])

    @property
    def label(self) -> str:
        return f"{self.root.name} {self.scale.name}"

    def note_name(self, pitch_class: int) -> str:
        return self.names[pitch_class % 12]

    def chord_note_name(self, pitch_class: int) -> str:
        """A chord root is never written Fb or Gx, however the scale spells it."""
        name = self.note_name(pitch_class)
        if name in CHORD_ROOT_NAMES:
            return name
        return (FLAT_NAMES if self.uses_flats else SHARP_NAMES)[pitch_class % 12]


# The spelling a musician actually writes for each key. D# minor and Eb minor
# need the same number of accidentals, so counting them cannot choose; practice
# chooses Eb minor.
CONVENTIONAL_MAJOR = ("C", "Db", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B")
CONVENTIONAL_MINOR = ("C", "C#", "D", "Eb", "E", "F", "F#", "G", "G#", "A", "Bb", "B")


def key_for(tonic: int, mode: str, spelling: str | None = None) -> Key:
    """Pick the conventional spelling of a key from a pitch class and a mode."""
    if spelling and spelling in ROOTS_BY_NAME:
        return Key(spelling, mode)
    minorish = mode in ("minor", "aeolian", "harmonic_minor", "melodic_minor",
                        "dorian", "phrygian", "locrian", "minor_pentatonic",
                        "blues", "diminished_wh")
    preferred = (CONVENTIONAL_MINOR if minorish else CONVENTIONAL_MAJOR)[tonic % 12]

    best: Key | None = None
    for root in ROOTS:
        if root.pitch_class != tonic % 12 or root.name == "Cb":
            continue
        candidate = Key(root, mode)
        # Never a spelling that cannot spell its own scale - that is what rules
        # out, say, D# major, whose seventh degree needs a triple sharp.
        if len(candidate.names) < 12:
            continue
        if best is None:
            best = candidate
            continue
        # Fewest accidentals wins; convention breaks the tie.
        load, best_load = _accidental_load(candidate), _accidental_load(best)
        if (load, candidate.root.name != preferred) < (best_load, best.root.name != preferred):
            best = candidate
    return best or Key(SHARP_NAMES[tonic % 12], mode)


def _accidental_load(key: Key) -> int:
    return sum(len(key.names[pc]) - 1 for pc in key.active)


# ------------------------------------------------------------- chord reader --
# Ranking of the core qualities: how ordinary a third/fifth/seventh combination
# is. Lower is commoner. See ScaleView's CLAUDE.md for the measurements.
CORE_RANK = {
    "maj/P/none": 1, "min/P/none": 2,
    "maj/P/b7": 3, "min/P/b7": 4, "maj/P/maj7": 5,
    "min/b/b7": 6, "min/b/bb7": 7, "min/b/none": 8,
    "maj/#/none": 9,
    "sus4/P/none": 10, "sus2/P/none": 11,
    "min/P/maj7": 12,
    "maj/#/b7": 13, "maj/b/b7": 14, "maj/#/maj7": 15,
    "sus4/P/b7": 16, "sus2/P/b7": 17,
    "sus4/P/maj7": 18, "sus2/P/maj7": 19,
    # A missing third is a different chord, not a thinner one.
    "none/P/b7": 30, "none/P/maj7": 31,
    "none/b/maj7": 32, "none/b/b7": 33, "none/P/none": 34,
}

RANK_UNNAMED = {"maj": 25, "min": 25, "sus4": 70, "sus2": 70, "none": 90}
RANK_TWICE_ODD = 12
RANK_NO_FIFTH = 20       # a triad that has lost its fifth
RANK_NO_FIFTH7 = 4       # a seventh chord voiced as a shell
RANK_ELEVENTH = 6        # a sus4 carrying a seventh and a ninth: C11
COST_INVERSION = 14      # naming the bass after a slash
COST_NATURAL = 1         # an extension the chord's number already implies
COST_ADD = 2             # one that has to be spelled out as an add
COST_CLASH = 6           # a natural eleventh fighting a major third
COST_ALTERED = 5         # b9, #9, #11, b13 colouring a chord at home with it
COST_CLASHING = 18       # the same alteration where it does not belong
COST_SUS_EXTRA = 12      # a suspension does not carry added tones
COST_SIXTH = 4

SPECIAL = {
    "min/b/none": "dim", "min/b/bb7": "dim7", "min/b/b7": "min7b5",
    "maj/#/none": "aug", "maj/#/b7": "aug7", "maj/#/maj7": "maj7#5",
    "maj/b/b7": "7b5", "min/P/maj7": "minMaj7", "min/none/maj7": "minMaj7",
}

EXTENSION = {
    1: ("b9", True, None), 2: ("9", False, 9), 3: ("#9", True, None),
    5: ("11", False, 11), 6: ("#11", True, None), 8: ("b13", True, None),
}

ASSUMED_KEY = {0, 2, 4, 5, 7, 9, 11}


def _core(has: set[int]) -> tuple[str, str, str, set[int]]:
    """Read the intervals present into a third, a fifth and a seventh."""
    used = {0}
    if 4 in has:
        third = "maj"; used.add(4)
    elif 3 in has:
        third = "min"; used.add(3)
    elif 5 in has:
        third = "sus4"; used.add(5)
    elif 2 in has:
        third = "sus2"; used.add(2)
    else:
        third = "none"

    if 7 in has:
        fifth = "P"; used.add(7)
    elif 6 in has:
        fifth = "b"; used.add(6)
    elif 8 in has:
        fifth = "#"; used.add(8)
    else:
        fifth = "none"

    if 10 in has:
        seventh = "b7"; used.add(10)
    elif 11 in has:
        seventh = "maj7"; used.add(11)
    elif third == "min" and fifth == "b" and 9 in has:
        # A diminished triad takes the 9 as a doubly flattened seventh.
        seventh = "bb7"; used.add(9)
    else:
        seventh = "none"

    return third, fifth, seventh, used


def _core_name(third: str, fifth: str, seventh: str) -> str:
    special = SPECIAL.get(f"{third}/{fifth}/{seventh}")
    if special:
        return special

    base = "min" if third == "min" else ("sus4" if third == "sus4"
                                         else ("sus2" if third == "sus2" else ""))
    if seventh == "b7":
        sev = "7"
    elif seventh == "bb7":
        sev = "dim7"
    elif seventh == "maj7":
        sev = "Maj7" if third == "min" else "maj7"
    else:
        sev = ""
    alt = "b5" if fifth == "b" else ("#5" if fifth == "#" else "")

    # Sevenths are written before a sus, not after it: 7sus4, never sus47.
    name = (sev + base) if third in ("sus4", "sus2") else (base + sev)
    name += alt
    # A bare altered fifth has to be bracketed or the symbol reads as a note
    # name: C(b5) is a chord on C, Cb5 looks like one on C flat.
    if name == alt and alt:
        name = f"({alt})"
    return name


def _rank_of(third: str, fifth: str, seventh: str) -> int:
    if fifth == "none":
        rank = CORE_RANK.get(f"{third}/P/{seventh}", RANK_UNNAMED[third])
        return rank + (RANK_NO_FIFTH if seventh == "none" else RANK_NO_FIFTH7)
    rank = CORE_RANK.get(f"{third}/{fifth}/{seventh}")
    if rank is not None:
        return rank
    return RANK_UNNAMED[third] + (RANK_TWICE_ODD if seventh != "none" else 0)


def analyse(has: set[int], root: int, bass: int) -> tuple[str, int, int]:
    """Name the intervals in `has` (relative to `root`), and say what it cost."""
    third, fifth, seventh, used = _core(has)
    rank = _rank_of(third, fifth, seventh)
    name, cost = _core_name(third, fifth, seventh), rank

    naturals: dict[int, bool] = {}
    altered: list[str] = []
    sixth = False
    as_eleventh = False

    for interval in range(1, 12):
        if interval not in has or interval in used:
            continue
        if interval == 9:
            if seventh == "none":
                sixth = True
            else:
                naturals[13] = True
            continue
        extension = EXTENSION.get(interval)
        if extension and extension[1]:
            altered.append(extension[0])
        elif extension:
            naturals[extension[2]] = True
        else:
            # Only 11 can arrive here: the major seventh left over when a
            # flattened one already took the seventh's place.
            altered.append("maj7")

    if seventh not in ("none", "bb7"):
        # A stacked number claims everything under it, so it may only be used
        # when the ninth is actually played; an altered ninth still fills that
        # place. Anything the number does not account for is bracketed.
        ninth = bool(naturals.get(9)) or any(t in ("b9", "#9") for t in altered)

        number = None
        if ninth and naturals.get(13):
            number = 13
        elif ninth and naturals.get(11) and third != "maj":
            number = 11
        elif naturals.get(9):
            number = 9

        if (third == "sus4" and seventh == "b7" and naturals.get(9)
                and fifth in ("P", "none")):
            # A sus4 carrying a seventh and a ninth is how an eleventh chord is
            # voiced - the third is left out because it would clash with the
            # eleventh - so it is named as one rather than as a suspension.
            name, number, as_eleventh = "11", 11, True
            naturals[11] = True
            cost = RANK_ELEVENTH + (RANK_NO_FIFTH7 if fifth == "none" else 0)
        elif number:
            name = name.replace("7", str(number), 1)

        spare = []
        for degree in (9, 11, 13):
            if not naturals.get(degree):
                continue
            implied = (number is not None and degree <= number
                       and not (degree == 11 and third == "maj"))
            if implied:
                cost += COST_NATURAL
            else:
                cost += COST_CLASH if (degree == 11 and third == "maj") else COST_ADD
                spare.append(degree)
        if spare:
            name += "(" + ",".join(str(d) for d in spare) + ")"
    else:
        # No seventh, so nothing stacks: everything above the triad is an add.
        if sixth:
            cost += COST_SIXTH
            mark = "b5" if fifth == "b" else ("#5" if fifth == "#" else "")
            if naturals.get(9) and third in ("maj", "min"):
                naturals.pop(9, None)
                name = ("min6/9" if third == "min" else "6/9") + mark
                cost += COST_ADD
            elif third == "min":
                name = "min6" + mark
            elif third == "maj":
                name = "aug6" if fifth == "#" else ("6" + mark)
            elif third == "none":
                name = "6" + mark
            else:
                name += "(add6)"
        for degree in (9, 11, 13):
            if naturals.get(degree):
                cost += COST_CLASH if (degree == 11 and third == "maj") else COST_ADD
                name += ("add" if name == "" else "Add") + str(degree)

    dominant = third == "maj" and seventh == "b7"
    triad = third in ("maj", "min") and fifth == "P"
    for token in altered:
        # A complete triad is allowed to carry an alteration, which is what
        # Scaler does - but not a b13, whose note is almost always a chord tone
        # of something plainer.
        at_home = (fifth not in ("b", "#") and token != "maj7"
                   and (token == "#11" or dominant or (triad and token != "b13")))
        # A flattened sixth is a b13 only when a seventh is under it; without
        # one it is an added flat sixth. Only the printed name changes.
        if token == "b13" and seventh == "none":
            shown = "b6"
        elif token == "maj7":
            shown = "(maj7)"
        else:
            shown = token
        cost += COST_ALTERED if at_home else COST_CLASHING
        name += ("add" if (name == "" and seventh == "none") else "") + shown

    if third in ("sus4", "sus2") and not as_eleventh:
        carried = len(altered) + sum(1 for d in (9, 11, 13) if naturals.get(d))
        carried += 1 if sixth else 0
        cost += carried * COST_SUS_EXTRA

    # A missing third is the one omission that has to be said out loud, and it
    # is said last: maj7b5(no3), not maj7(no3)b5.
    if third == "none":
        name = "5" if name == "" else name + "(no3)"

    if root != bass:
        cost += COST_INVERSION
    return name, cost, rank


def detect_chord(pitch_classes, bass: int | None = None,
                 key: Key | None = None) -> str | None:
    """Name a set of pitch classes. `bass` decides inversions.

    Returns None for an empty set; returns the notes spelled out when there is
    no chord to find, which is what ScaleView shows rather than guessing.
    """
    classes = {pc % 12 for pc in pitch_classes}
    if not classes:
        return None
    if bass is None:
        bass = min(classes)
    bass %= 12
    key = key or Key("C", "major")
    name_of = key.chord_note_name

    if len(classes) == 1:
        return name_of(next(iter(classes)))

    def spell_out() -> str:
        return " ".join(name_of(pc) for pc in range(12) if pc in classes)

    # Two notes are an interval rather than a chord, and only the bare fifth
    # has a name of its own.
    if len(classes) == 2:
        for root in range(12):
            if root in classes and (root + 7) % 12 in classes:
                name = name_of(root) + "5"
                return name if root == bass else f"{name}/{name_of(bass)}"
        return spell_out()

    # Past a certain thickness there is no chord left to find, only a cluster.
    if len(classes) > 7:
        return spell_out()

    in_key = key.active if key else ASSUMED_KEY
    best = None
    for root in sorted(classes):
        has = {(pc - root) % 12 for pc in classes}
        name, cost, rank = analyse(has, root, bass)
        fit = (100 if root in in_key else 0) + sum(1 for pc in classes if pc in in_key)
        if (best is None or cost < best[1]
                or (cost == best[1] and fit > best[3])
                or (cost == best[1] and fit == best[3] and rank < best[2])):
            best = (name, cost, rank, fit, root)

    name, _cost, _rank, _fit, root = best
    symbol = name_of(root) + name
    return symbol if root == bass else f"{symbol}/{name_of(bass)}"
