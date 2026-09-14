"""Progressions generated from chord *function* rather than picked from a list.

The model follows the taxonomy in the project's harmony notes:

* Chords fall into three functions - **tonic**, **predominant**, **dominant** -
  and the basic motion is T -> S -> D -> T.
* Every chord in a key has its own dominant, so any target can be approached by
  its **secondary dominant** (V7/x), its **substitute dominant** a tritone away
  (SubV7/x, resolving down a semitone), the **backdoor** dominant a whole step
  below (bVII7/x), or a **leading-tone diminished** chord.
* A dominant is usually preceded by its **related II** - the chord a perfect
  fifth above it - so the roots fall by fifths into the target.
* A target can also be reached plagally: IV, the **minor plagal** iv, or the
  phrygian bII.

Progressions are built by backward chaining from the tonic: pick a cadence,
then keep prefixing approach chords until the phrase is long enough. That means
the generator can write a progression it has never been given, in any mode, and
can always say why each chord is there - every chord carries the function that
put it in.

Diatonic chord qualities are derived by stacking thirds inside the mode itself,
so a dorian IV comes out major and an aeolian bVI comes out major without any
of it being written down per mode.
"""

from __future__ import annotations

import random
from dataclasses import dataclass

from middaw import cadence as cadences
from middaw.theory import (PARENT_SCALE, QUALITIES, ROMAN_BY_INTERVAL, SCALES,
                           roman_for_degree, scale_pitch_classes)

#: Modes where borrowing a major V is idiomatic. Dorian, phrygian and
#: mixolydian are *modal*: their flat seventh is the whole point of them, and
#: raising it to make a leading tone turns them into minor.
MINOR_KEY_MODES = {"minor", "aeolian", "harmonic_minor", "melodic_minor"}

TONIC = "tonic"
PREDOMINANT = "predominant"
DOMINANT = "dominant"

# Scale degree (index into the seven-note mode) -> function.
DEGREE_FUNCTION = {
    0: TONIC,          # I
    1: PREDOMINANT,    # ii
    2: TONIC,          # iii - an alternate tonic
    3: PREDOMINANT,    # IV
    4: DOMINANT,       # V
    5: TONIC,          # vi - the other alternate tonic
    6: DOMINANT,       # vii
}

_MINOR_QUALITIES = {"min", "dim", "min7", "min7b5", "dim7", "min6", "min9",
                    "minmaj7", "minadd9"}

_QUALITY_SUFFIX = {
    "maj": "", "min": "", "dim": "o", "aug": "+",
    "maj7": "maj7", "minmaj7": "maj7", "augmaj7": "+maj7", "aug7": "+7",
    "dom7": "7", "min7": "7", "min7b5": "0", "dim7": "o7",
    "maj6": "6", "min6": "6",
}


@dataclass(frozen=True)
class FunctionalChord:
    """One chord, and the reason it is there."""

    symbol: str          # a roman numeral `theory.parse_roman` can read
    root: int            # pitch class
    function: str
    label: str = ""      # how a musician names the function, e.g. "V7/vi"
    target: int | None = None   # the pitch class this chord resolves to
    numeral: str = ""    # the bare degree, e.g. "vi" - what a target is called

    @property
    def display(self) -> str:
        return self.label or self.symbol


# ----------------------------------------------------------------- helpers --
def _quality_of(intervals: tuple[int, ...]) -> str:
    for name, shape in QUALITIES.items():
        if tuple(sorted(shape)) == tuple(sorted(intervals)):
            return name
    return "maj"


def _apply_case(numeral: str, quality: str) -> str:
    accidental = ""
    while numeral and numeral[0] in "b#x":
        accidental += numeral[0]
        numeral = numeral[1:]
    if quality in _MINOR_QUALITIES:
        numeral = numeral.lower()
    return accidental + numeral + _QUALITY_SUFFIX.get(quality, "")


def roman_for(root_interval: int, quality: str) -> str:
    """'bIII' + min7 -> 'biii7'. The numeral's case carries major/minor."""
    return _apply_case(ROMAN_BY_INTERVAL[root_interval % 12], quality)


def roman_for_scale_degree(degree: int, interval: int, quality: str) -> str:
    """As `roman_for`, but spelled for the degree it occupies in the mode."""
    return _apply_case(roman_for_degree(degree, interval), quality)


def diatonic_chords(tonic: int, mode: str, sevenths: bool = False) -> list[FunctionalChord]:
    """Every chord of the mode, built by stacking thirds inside the mode."""
    parent = PARENT_SCALE.get(mode, mode)
    scale = scale_pitch_classes(tonic, parent)
    if len(scale) != 7:
        scale = scale_pitch_classes(tonic, "major")

    steps = SCALES.get(parent, SCALES["major"])
    if len(steps) != 7:
        steps = SCALES["major"]

    chords = []
    size = 4 if sevenths else 3
    for degree in range(7):
        picks = [scale[(degree + 2 * step) % 7] for step in range(size)]
        root = picks[0]
        intervals = tuple(sorted((pc - root) % 12 for pc in picks))
        quality = _quality_of(intervals)
        numeral = roman_for_scale_degree(degree, steps[degree],
                                         "min" if quality in _MINOR_QUALITIES else "maj")
        chords.append(FunctionalChord(
            symbol=roman_for_scale_degree(degree, steps[degree], quality),
            root=root,
            function=DEGREE_FUNCTION[degree],
            numeral=numeral,
        ))
    return chords


def chords_by_function(tonic: int, mode: str, sevenths: bool = False) -> dict[str, list[FunctionalChord]]:
    grouped: dict[str, list[FunctionalChord]] = {TONIC: [], PREDOMINANT: [], DOMINANT: []}
    for chord in diatonic_chords(tonic, mode, sevenths):
        grouped[chord.function].append(chord)
    return grouped


def _target_name(tonic: int, target_root: int, mode: str) -> str:
    """How a musician writes the target of a secondary chord: 'vi', 'IV', ...

    Always the bare degree. 'V7/V' is what gets written, never 'V7/V7' - the
    slash names where the chord is going, not the chord standing there.
    """
    for chord in diatonic_chords(tonic, mode):
        if chord.root == target_root % 12:
            return chord.numeral or chord.symbol
    return ROMAN_BY_INTERVAL[(target_root - tonic) % 12]


# ------------------------------------------------------------- approaches --
def secondary_dominant(tonic: int, mode: str, target: FunctionalChord,
                       kind: str = "V7") -> FunctionalChord:
    """The dominant that resolves to `target`.

    `kind` picks which one: the plain fifth-below V7, the tritone substitute a
    semitone above, the backdoor a whole step below, or a leading-tone
    diminished seventh. All four resolve to the same place; they differ in how
    the roots move into it.
    """
    is_tonic = target.root == tonic
    target_name = target.numeral or _target_name(tonic, target.root, mode)
    suffix = "" if is_tonic else "/" + target_name
    if kind == "SubV7":
        root, quality, kind_name = (target.root + 1) % 12, "dom7", "SubV7"
    elif kind == "bVII7":
        root, quality, kind_name = (target.root + 10) % 12, "dom7", "bVII7"
    elif kind == "viio7":
        root, quality, kind_name = (target.root + 11) % 12, "dim7", "viio7"
    else:
        root, quality, kind_name = (target.root + 7) % 12, "dom7", "V7"

    # V7 of a diatonic target is written the way musicians write it, and the
    # way parse_roman reads it. The others have no such notation, so they keep
    # their plain roman symbol and carry the function in the label.
    if kind == "V7":
        symbol = "V7" if is_tonic else f"V7/{target_name}"
    else:
        symbol = roman_for((root - tonic) % 12, quality)

    return FunctionalChord(symbol=symbol, root=root, function=DOMINANT,
                           label=kind_name + suffix, target=target.root)


def related_two(tonic: int, mode: str, dominant: FunctionalChord) -> FunctionalChord:
    """The chord a perfect fifth above a dominant, so the roots fall by fifths.

    Half-diminished when the chord it is heading for is minor, which is what
    makes a minor ii-V-i sound like one rather than like a major ii-V. Where
    the key already has a chord on that root, that chord is used as it stands -
    borrowing one would be a chromatic decision, and this is not the place
    that decision gets made.
    """
    root = (dominant.root + 7) % 12
    diatonic = {c.root: c for c in diatonic_chords(tonic, mode, sevenths=True)}
    target = diatonic.get(dominant.target if dominant.target is not None else tonic)
    minor_target = target is not None and target.symbol[:1].islower()
    quality = "min7b5" if minor_target else "min7"
    if dominant.target in (None, tonic) or target is None:
        suffix = ""
    else:
        suffix = "/" + (target.numeral or target.symbol)
    return FunctionalChord(roman_for((root - tonic) % 12, quality), root,
                           PREDOMINANT, "ii" + suffix, target=dominant.root)


# ------------------------------------------------------------- generation --
# Which function may precede which, read backwards from the chord you are on.
PRECEDING_FUNCTION = {
    TONIC: ((DOMINANT, 0.55), (PREDOMINANT, 0.35), (TONIC, 0.10)),
    PREDOMINANT: ((TONIC, 0.50), (PREDOMINANT, 0.30), (DOMINANT, 0.20)),
    DOMINANT: ((PREDOMINANT, 0.65), (TONIC, 0.35)),
}

# Within a function, how ordinary each scale degree is.
DEGREE_WEIGHT = {0: 6.0, 1: 3.0, 2: 1.2, 3: 4.0, 4: 6.0, 5: 2.5, 6: 0.9}


def _weighted(rng: random.Random, options):
    total = sum(w for w, _ in options)
    if total <= 0:
        return None
    roll = rng.random() * total
    for weight, value in options:
        roll -= weight
        if roll <= 0:
            return value
    return options[-1][1]


def closing_chords(tonic: int, mode: str, kind: str,
                   sevenths: bool) -> list[FunctionalChord]:
    """The chords that spell a given cadence in this key."""
    cadence = cadences.get(kind)
    if cadence is None:
        return []
    diatonic = diatonic_chords(tonic, mode, sevenths=sevenths)
    chords = []
    for position, degree in enumerate(cadence.degrees):
        chord = diatonic[degree]
        # The approach chord of an authentic or deceptive cadence wants the
        # leading-tone pull, so a minor key borrows a major V - that is what
        # harmonic minor exists for. A modal key keeps its own dominant.
        if (cadence.seventh and position == 0 and degree == 4
                and (mode in MINOR_KEY_MODES or not chord.symbol[:1].islower())):
            chord = FunctionalChord("V7", chord.root, DOMINANT, "V7", tonic, "V")
        chords.append(chord)
    return chords


def _skeleton(rng: random.Random, tonic: int, mode: str, length: int,
              sevenths: bool, cadence: str | None = None) -> list[FunctionalChord]:
    """A purely diatonic backbone of the right length, ending at the cadence."""
    diatonic = diatonic_chords(tonic, mode, sevenths=sevenths)
    by_function: dict[str, list[tuple[float, FunctionalChord]]] = {
        TONIC: [], PREDOMINANT: [], DOMINANT: []}
    for degree, chord in enumerate(diatonic):
        by_function[chord.function].append((DEGREE_WEIGHT[degree], chord))

    progression = closing_chords(tonic, mode, cadence, sevenths) or [diatonic[0]]
    progression = progression[-length:]

    # A section that ends on a cadence still has to begin somewhere, and most
    # begin at home - it is how the key gets established in the first place.
    # The flowchart allows it: the tonic may progress directly to any function.
    open_at_home = bool(cadence) and length > len(progression) and rng.random() < 0.8
    if open_at_home:
        length -= 1
    while len(progression) < length:
        head = progression[0]
        wanted = _weighted(rng, [(w, f) for f, w in PRECEDING_FUNCTION[head.function]])
        options = [(w, c) for w, c in by_function[wanted] if c.root != head.root]
        # Discourage the chord two places back, or an eight-bar phrase collapses
        # into a two-chord oscillation - I V I V I V I V.
        if len(progression) > 1:
            recent = progression[1].root
            options = [(w * (0.25 if c.root == recent else 1.0), c) for w, c in options]
        chord = _weighted(rng, options or by_function[wanted])
        if chord is None:
            break
        progression.insert(0, chord)

    if open_at_home and progression[0].root != tonic:
        progression.insert(0, diatonic[0])
    return progression


def _muddies_the_tonic(chord: FunctionalChord, tonic: int, home_is_minor: bool) -> bool:
    """Would this chord blur the key by sitting on the tonic without being it?

    I7 as the dominant of IV is ordinary where home is already a major chord -
    it is how mixolydian and the blues work. Everything else standing on the
    tonic root competes with the tonic instead of decorating it: a diminished
    or half-diminished chord there says the home note is not home.
    """
    if chord.root != tonic or chord.function == TONIC:
        return False
    is_dominant_seventh = chord.symbol.endswith("7") and chord.symbol[:1].isupper()
    return home_is_minor or not is_dominant_seventh


def _two_label(tonic: int, mode: str, dominant: FunctionalChord, diatonic) -> str:
    if dominant.target in (None, tonic):
        return "ii"
    target = diatonic.get(dominant.target)
    return "ii/" + (target.numeral or target.symbol) if target else "ii"


def _decorate(rng: random.Random, tonic: int, mode: str,
              progression: list[FunctionalChord],
              chromaticism: float, protect: int = 0) -> list[FunctionalChord]:
    """Tonicise chords, substitute dominants, and add related II chords.

    Every target here is a diatonic chord of the key, which is what keeps a
    secondary dominant sounding like one rather than like a modulation.
    """
    out = list(progression)
    diatonic = diatonic_chords(tonic, mode, sevenths=True)
    # Read the home quality off the mode, not off progression[0]: the skeleton
    # is built backwards, so the tonic is at the end of it, not the start.
    home_is_minor = diatonic[0].symbol[:1].islower()
    diatonic_symbols = {c.root: c.symbol for c in diatonic}

    # The cadence is the point of the phrase; decoration must not rewrite it.
    guarded = set(range(len(out) - protect, len(out))) if protect else set()

    def accept(index: int, chord: FunctionalChord) -> bool:
        if index in guarded or _muddies_the_tonic(chord, tonic, home_is_minor):
            return False
        out[index] = chord
        return True

    # 1. Tonicise: the chord before a target becomes that target's dominant.
    #    The home chord is skipped because the skeleton already gave it a V.
    for index in range(1, len(out)):
        target = out[index]
        if target.root == tonic:
            continue
        if rng.random() > chromaticism * 0.8:
            continue
        accept(index - 1, secondary_dominant(tonic, mode, target))

    # 2. Substitute a dominant with a tritone sub, a backdoor, or a diminished.
    for index, chord in enumerate(out):
        if chord.function != DOMINANT or chord.target is None:
            continue
        if rng.random() > chromaticism * 0.45:
            continue
        target = _chord_at(tonic, mode, chord.target)
        kind = _weighted(rng, [(3.0, "SubV7"), (2.0, "bVII7"), (1.2, "viio7")])
        accept(index, secondary_dominant(tonic, mode, target, kind))

    # 3. Put the related II in front of a dominant that has room for one.
    for index in range(len(out) - 1, 0, -1):
        chord = out[index]
        if chord.function != DOMINANT or chord.label.startswith("viio7"):
            continue
        previous = out[index - 1]
        if previous.function == PREDOMINANT and previous.label.startswith("ii"):
            continue
        if rng.random() > 0.35 + 0.4 * chromaticism:
            continue
        two = related_two(tonic, mode, chord)
        # The related II belongs to the key of the chord it is heading for, not
        # to the home key - the ii of F minor is Gm7b5, not Gm7 - so it is
        # often a borrowed chord, and borrowing is a chromatic decision.
        if diatonic_symbols.get(two.root) != two.symbol and rng.random() > chromaticism:
            continue
        accept(index - 1, two)
    return out


def _raise_the_leading_tone(rng: random.Random, tonic: int, mode: str,
                            progression: list[FunctionalChord]) -> list[FunctionalChord]:
    """Borrow a major V in a minor key, which is what harmonic minor is for.

    A diatonic minor v has no leading tone and barely pulls home. Modal writing
    uses it deliberately, so this is a coin toss rather than a rule.
    """
    out = []
    for chord in progression:
        minor_dominant = (chord.function == DOMINANT
                          and chord.root == (tonic + 7) % 12
                          and chord.symbol[:1].islower()
                          and mode in MINOR_KEY_MODES)
        if minor_dominant and rng.random() < 0.6:
            out.append(FunctionalChord("V7", chord.root, DOMINANT, "V7", tonic, "V"))
        else:
            out.append(chord)
    return out


def _chord_at(tonic: int, mode: str, root: int) -> FunctionalChord:
    for chord in diatonic_chords(tonic, mode, sevenths=True):
        if chord.root == root % 12:
            return chord
    return FunctionalChord(roman_for((root - tonic) % 12, "maj"), root % 12, TONIC)


def generate_progression(tonic: int, mode: str, length: int = 4,
                         chromaticism: float = 0.2, sevenths: float = 0.3,
                         rng: random.Random | None = None,
                         start_on_tonic: bool = True,
                         cadence: str | None = None) -> list[FunctionalChord]:
    """Write a progression of `length` chords in the given key.

    A diatonic skeleton is built backwards from the cadence - from home when
    none is named - then decorated with the secondary dominants, substitutes
    and related II chords that `chromaticism` allows. Nothing is drawn from a
    table of known progressions, so the result can be one nobody wrote down,
    but every chord can still say why it is there.

    Naming a `cadence` fixes how the phrase ends and stops the closing chords
    being decorated away, which is what lets a section ask a question and the
    next one answer it.
    """
    rng = rng or random.Random()
    length = max(2, min(16, int(length)))
    use_sevenths = rng.random() < sevenths

    progression = _skeleton(rng, tonic, mode, length, use_sevenths, cadence)
    progression = _raise_the_leading_tone(rng, tonic, mode, progression)
    protect = min(length, len(cadences.get(cadence).degrees)) if cadences.get(cadence) else 0
    progression = _decorate(rng, tonic, mode, progression,
                            max(0.0, min(1.0, chromaticism)), protect=protect)

    # A named cadence is the whole point of the phrase, so it stays at the end.
    if cadence:
        return progression

    if start_on_tonic and progression[0].root != tonic:
        # A loop is cyclic, so rotating home to the front keeps every
        # resolution intact - the last chord now resolves across the repeat.
        for index, chord in enumerate(progression):
            if chord.root == tonic and chord.function == TONIC:
                progression = progression[index:] + progression[:index]
                break
    return progression


def recadence(symbols: list[str], labels: list[str], tonic: int, mode: str,
              kind: str, sevenths: bool = False) -> tuple[list[str], list[str]]:
    """Re-end an existing progression with a different cadence.

    A refrain that stops on the dominant and the same refrain that closes are
    the same music differently finished, so only the closing chords change.
    """
    closing = closing_chords(tonic, mode, kind, sevenths)
    if not closing or not symbols:
        return list(symbols), list(labels)
    tail = min(len(closing), len(symbols))
    return (list(symbols[:len(symbols) - tail]) + [c.symbol for c in closing[-tail:]],
            list(labels[:len(labels) - tail]) + [c.display for c in closing[-tail:]])
