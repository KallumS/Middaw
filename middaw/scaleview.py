"""Scales, key-aware spelling and chord reading.

Ported from ScaleView Pro (github.com/KallumS/scaleview-for-reaper, GPL v3), the
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

Since ScaleView Pro df4ea43 (October 2026) the reader also takes Starting
Blocks' chords as its dictionary of roots: where the notes are a Blocks chord,
the name is on one of Blocks' roots for them. One table of that is the key's
own chords, so the `key` passed to `detect_chord` decides readings, not only
draws; C major when none is given, as ScaleView assumes with no scale chosen.

The ranking constants and their reasoning are ScaleView's; see that repo's
CLAUDE.md for the measurements behind each one. Keep the two in step: a fix
here probably belongs there too. In step with ScaleView Pro's reader at
df4ea43, checked against the Lua script itself over 157,740 readings in ten
keys.
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
    # maj7b5 was missing, though players write it constantly as the Lydian
    # tonic: without it D D# G A read Dsus4b9 rather than D#maj7b5/D.
    "maj/b/maj7": 16,
    "sus4/P/b7": 17, "sus2/P/b7": 18,
    "sus4/P/maj7": 19, "sus2/P/maj7": 20,
    # A missing third is a different chord, not a thinner one. One whose fifth
    # is *also* altered is odd twice over, so those two sit past COST_INVERSION
    # from an unnamed quality with a third (25): D E A# reads Bb(b5)/E, not
    # E7b5(no3). The perfect-fifth ones stay, which keeps C G Bb as C7(no3).
    "none/P/b7": 30, "none/P/maj7": 31, "none/P/none": 34,
    "none/b/maj7": 41, "none/b/b7": 42,
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
# A minor sixth is the one sixth that is also something else: A C E F# is
# Amin6 and equally F#min7b5. The two tied exactly, and the half-diminished is
# what Scaler, jazznet and the DCML and When in Rome analysts write.
COST_MIN_SIXTH = 5

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
# The same assumption's first, third and fifth degrees, for the doubled-degree
# rule. Change the assumed key and this has to change with it.
ASSUMED_TONIC = {0, 4, 7}


def _core(has: set[int], prefer_sharp_five: bool = False
          ) -> tuple[str, str, str, set[int]]:
    """Read the intervals present into a third, a fifth and a seventh.

    Where both a flattened and a raised fifth sound, which one is *the* fifth
    is a choice, so `prefer_sharp_five` asks for the other reading and
    `analyse` costs both: C E F# G# B is Cmaj7#5#11, not Cmaj7b5b13.
    """
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
    elif 6 in has and 8 in has and prefer_sharp_five:
        fifth = "#"; used.add(8)
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


def analyse_as(has: set[int], root: int, bass: int,
               prefer_sharp_five: bool = False) -> tuple[str, int, int]:
    """Name the intervals in `has` (relative to `root`), and say what it cost."""
    third, fifth, seventh, used = _core(has, prefer_sharp_five)
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
            cost += (COST_MIN_SIXTH if (third == "min" and fifth == "P")
                     else COST_SIXTH)
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
        # A diminished seventh carrying a ninth is a dim9: the number rises as
        # it does under any other seventh. Renamed only - the cost is what an
        # added tone costs, so which reading wins is untouched.
        if seventh == "bb7" and naturals.get(9):
            naturals.pop(9, None)
            name = name.replace("dim7", "dim9", 1)
            cost += COST_ADD
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
        # An altered fifth is no bar on a dominant standing on its own root:
        # 7#5b9, 7b5#9 and 7b9b13 are the altered dominants every lead sheet
        # writes. Only from the bass - from an inversion it read F A C G C#
        # over C as Aaug7#9/C.
        plain_fifth = fifth not in ("b", "#")
        at_home = (token != "maj7"
                   and ((dominant and (plain_fifth or root == bass))
                        or (plain_fifth and (token == "#11"
                                             or (triad and token != "b13")))))
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


def analyse(has: set[int], root: int, bass: int) -> tuple[str, int, int]:
    """With both fifths sounding and no perfect one, cost both readings."""
    name, cost, rank = analyse_as(has, root, bass, False)
    if 6 in has and 8 in has and 7 not in has:
        alt_name, alt_cost, alt_rank = analyse_as(has, root, bass, True)
        if alt_cost < cost:
            return alt_name, alt_cost, alt_rank
    return name, cost, rank


def tonic_degrees(key: Key) -> set[int]:
    """The first, third and fifth degrees of the key, read off its scale."""
    intervals = key.scale.intervals
    return {(key.tonic + intervals[degree]) % 12
            for degree in (0, 2, 4) if degree < len(intervals)}


def read_as_root_position(root: int, bass: int, voices: dict[int, int],
                          key: Key) -> bool:
    """A doubled degree of the key claims the bass.

    A root that is a first, third or fifth degree of the key and sounds in
    more than one octave is how a chord is voiced in root position, so the
    slash comes off: E G C C is C. It can only ever remove a slash. The cost
    model is untouched; this decides how the winner is written down.
    """
    if root == bass:
        return True
    if voices.get(root, 0) < 2:
        return False
    return root in tonic_degrees(key)


# Starting Blocks' chords decide which roots a chord can have. Where the notes
# are a Blocks chord - one of its chord types on any root, in any inversion,
# or one of the key's own chords on its degrees - the name is on one of
# Blocks' roots for them, the reader's cost choosing between them as always.
# Other notes are read as before. Copied unchanged from Starting Blocks'
# `sb_engine.lua` (`M.CHORDS` intervals, `M.DIATONIC` offsets) at fc4dd32, by
# way of ScaleView Pro df4ea43. Measured there: on Blocks' own 670,248 chords
# the root is Blocks' 74.4% of the time, against 52% before.
BLOCKS_CHORDS = (
    (0, 4, 7), (0, 3, 7), (0, 3, 6), (0, 4, 8), (0, 4, 6), (0, 7),
    (0, 4, 7, 9), (0, 3, 7, 9), (0, 4, 7, 9, 14), (0, 3, 7, 9, 14), (0, 4, 7, 10), (0, 4, 7, 11),
    (0, 3, 7, 10), (0, 3, 7, 11), (0, 3, 6, 10), (0, 3, 6, 9), (0, 4, 8, 10), (0, 4, 8, 11),
    (0, 4, 6, 10), (0, 3, 6, 11), (0, 4, 7, 9, 10),
    (0, 4, 7, 10, 14), (0, 4, 7, 11, 14), (0, 3, 7, 10, 14), (0, 3, 7, 11, 14), (0, 4, 7, 10, 14, 17),
    (0, 4, 7, 11, 14, 17), (0, 3, 7, 10, 14, 17), (0, 4, 7, 10, 14, 17, 21), (0, 4, 7, 11, 14, 17, 21),
    (0, 3, 7, 10, 14, 17, 21),
    (0, 4, 7, 10, 13), (0, 4, 7, 10, 15), (0, 4, 7, 10, 18), (0, 4, 7, 10, 20), (0, 4, 8, 10, 13),
    (0, 4, 8, 10, 15), (0, 4, 6, 10, 13), (0, 4, 8, 10, 13, 15), (0, 4, 7, 10, 13, 21),
    (0, 4, 7, 11, 18), (0, 3, 6, 10, 14), (0, 4, 8, 10, 14), (0, 4, 6, 10, 14), (0, 4, 7, 10, 14, 18),
    (0, 4, 8, 11, 18), (0, 4, 6, 10, 13, 21),
    (0, 2, 7), (0, 5, 7), (0, 5, 7, 10), (0, 5, 7, 10, 14), (0, 5, 7, 11), (0, 4, 7, 14),
    (0, 3, 7, 14), (0, 4, 5, 7), (0, 4, 7, 17), (0, 4, 7, 21), (0, 2, 4, 7), (0, 2, 3, 7),
    (0, 5, 10), (0, 5, 10, 15), (0, 7, 14), (0, 2, 4), (0, 1, 2), (0, 2, 4, 5),
    (0, 6, 10, 16, 21, 26), (0, 4, 6, 7, 10, 13), (0, 6, 10, 15), (0, 5, 10, 15, 19), (0, 5, 6, 7),
    (0, 1, 6), (0, 6, 7), (0, 1, 4, 5, 8, 9), (0, 7, 9, 13, 16), (0, 8, 11, 16, 21), (0, 4, 10),
    (0, 4, 6, 10), (0, 4, 7, 10),
)
# Scale degrees above the one chosen: triad, 7th, 9th, 11th, 13th, 6th,
# sus2, sus4, 5th.
BLOCKS_DIATONIC = (
    (0, 2, 4), (0, 2, 4, 6), (0, 2, 4, 6, 8), (0, 2, 4, 6, 8, 10), (0, 2, 4, 6, 8, 10, 12),
    (0, 2, 4, 5), (0, 1, 4), (0, 3, 4), (0, 4),
)


def mask_from(classes, root: int) -> int:
    """A set of pitch classes as a 12-bit mask, read from a root."""
    mask = 0
    for pc in classes:
        mask |= 1 << ((pc - root) % 12)
    return mask


# Every chord type, as the pitch classes it holds above its root.
BLOCKS_TYPES = {mask_from(shape, 0) for shape in BLOCKS_CHORDS}

# The key's own chords, built once per key: mask -> the roots it is built on.
_KEY_CHORDS: dict[tuple[int, str], dict[int, set[int]]] = {}


def blocks_key_chords(key: Key) -> dict[int, set[int]]:
    cache_key = (key.tonic, key.scale_id)
    chords = _KEY_CHORDS.get(cache_key)
    if chords is None:
        intervals = key.scale.intervals
        n = len(intervals)

        def pitch(degree: int) -> int:
            return key.tonic + intervals[degree % n] + 12 * (degree // n)

        chords = {}
        for degree in range(n):
            root = pitch(degree) % 12
            for offsets in BLOCKS_DIATONIC:
                mask = 0
                for o in offsets:
                    mask |= 1 << (pitch(degree + o) % 12)
                chords.setdefault(mask, set()).add(root)
        _KEY_CHORDS[cache_key] = chords
    return chords


def blocks_roots(classes: set[int], key: Key) -> set[int] | None:
    """The roots Blocks builds these notes on, or None if it builds them on none."""
    in_key = blocks_key_chords(key).get(mask_from(classes, 0), set())
    roots = {root for root in range(12)
             if root in classes
             and (root in in_key or mask_from(classes, root) in BLOCKS_TYPES)}
    return roots or None


def detect_chord(pitch_classes, bass: int | None = None,
                 key: Key | None = None) -> str | None:
    """Name a set of notes. `bass` decides inversions.

    `pitch_classes` may be MIDI notes rather than pitch classes: a pitch class
    sounding in more than one octave is what lets a doubled root of the key
    read as root position. Pitch classes alone are read exactly as before.
    `key` settles draws and supplies Blocks' chords; C major when not given.

    Returns None for an empty set; returns the notes spelled out when there is
    no chord to find, which is what ScaleView shows rather than guessing.
    """
    notes = {int(n) for n in pitch_classes}
    classes = {n % 12 for n in notes}
    if not classes:
        return None
    voices: dict[int, int] = {}
    for n in notes:
        voices[n % 12] = voices.get(n % 12, 0) + 1   # octaves it is sounding in
    if bass is None:
        bass = min(notes)
    bass %= 12
    key = key or Key("C", "major")
    name_of = key.chord_note_name
    in_key = key.active if key else ASSUMED_KEY
    count = len(classes)

    def written(root: int, quality: str) -> str:
        name = name_of(root) + quality
        if not read_as_root_position(root, bass, voices, key):
            name += "/" + name_of(bass)
        return name

    def fit_of(root: int) -> int:
        return (100 if root in in_key else 0) + sum(1 for pc in classes if pc in in_key)

    def better(cost, fit, slash, rank, best) -> bool:
        # The cheaper reading, then the key, then no slash, then the commoner
        # quality. C D G Bb over C is C7sus2, not GminAdd11/C.
        return (best is None or cost < best[0]
                or (cost == best[0] and fit > best[1])
                or (cost == best[0] and fit == best[1] and best[2] and not slash)
                or (cost == best[0] and fit == best[1] and slash == best[2]
                    and rank < best[3]))

    if count == 1:
        return name_of(bass)

    # A Blocks chord is named on one of Blocks' roots for it, chosen the way
    # the reader below chooses, in the reader's own words from that root.
    blocks = blocks_roots(classes, key)
    if blocks:
        pick = None
        for root in range(12):
            if root not in blocks:
                continue
            has = {(pc - root) % 12 for pc in classes}
            quality, cost, rank = analyse(has, root, bass)
            if count == 2:
                quality = ("5" if 7 in has else "maj(no5)" if 4 in has
                           else "min(no5)" if 3 in has else quality)
            fit, slash = fit_of(root), root != bass
            if better(cost, fit, slash, rank, pick):
                pick = (cost, fit, slash, rank, root, quality)
        return written(pick[4], pick[5])

    def spell_out() -> str:
        return " ".join(name_of(pc) for pc in range(12) if pc in classes)

    # Two notes are an interval rather than a chord, except the bare fifth and
    # a third. A third names a chord, and the missing fifth is said out loud:
    # printing C for C E would claim a G nobody is playing.
    if count == 2:
        for root in range(12):
            if root in classes and (root + 7) % 12 in classes:
                return written(root, "5")
        for root in range(12):
            if root in classes:
                quality = ("maj" if (root + 4) % 12 in classes
                           else "min" if (root + 3) % 12 in classes else None)
                if quality:
                    return written(root, quality + "(no5)")
        return spell_out()

    # Past a certain thickness there is no chord left to find, only a cluster.
    if count > 7:
        return spell_out()

    best = None
    for root in sorted(classes):
        has = {(pc - root) % 12 for pc in classes}
        name, cost, rank = analyse(has, root, bass)
        fit, slash = fit_of(root), root != bass
        if better(cost, fit, slash, rank, best):
            best = (cost, fit, slash, rank, root, name)
    return written(best[4], best[5])
