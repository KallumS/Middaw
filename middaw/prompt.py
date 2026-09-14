"""Prompt -> `MusicSpec`.

Two layers:

1. **Explicit directives** - regexes for the things a musician states outright
   ("in F# minor", "at 92 bpm", "6/8", "8 bars"). These always win.
2. **Vocabulary matching** - controlled-vocabulary tags from
   `data/vocab/tags.json` supply everything the prompt did not state.

Anything the parser did not understand is reported back on the spec as
`unmatched_terms`, which is the cheapest possible source of truth for what the
lexicon is still missing.
"""

from __future__ import annotations

import random
import re

from middaw.form import snap_to_ladder
from middaw.functional import generate_progression
from middaw.spec import MusicSpec
from middaw.parts import ALL_VOICES, PARTS, TREATMENTS, VOICE_PARTS
from middaw.theory import (BLUES_MODES, PITCH_CLASSES, SCALES,
                           harmonic_pitch_classes, parse_note_name, parse_roman)
from middaw.vocab import Match, Vocabulary, load_vocabulary, normalise

#: A form implies the music it belongs to, when the prompt named no style.
FORM_IMPLIES_GENRE = {"fugue": "baroque", "sonata": "classical",
                      "rondo": "classical", "rondo_seven": "classical",
                      "binary": "baroque", "binary_repeated": "baroque",
                      "ternary": "classical", "aaba": "jazz",
                      "strophic": "folk", "medley": "ragtime"}

_MODE_WORDS = {
    "major": "major", "maj": "major", "ionian": "major",
    "minor": "minor", "min": "minor", "aeolian": "aeolian",
    "harmonic minor": "harmonic_minor", "melodic minor": "melodic_minor",
    "dorian": "dorian", "phrygian": "phrygian", "lydian": "lydian",
    "mixolydian": "mixolydian", "locrian": "locrian",
    "pentatonic": "major_pentatonic", "major pentatonic": "major_pentatonic",
    "minor pentatonic": "minor_pentatonic", "blues scale": "blues",
    "whole tone": "whole_tone",
}

_NOTE_TOKEN = r"(?:[a-g](?:\s?(?:sharp|flat|#|b))?)"

_KEY_RE = re.compile(
    rf"\b(?:in|key\s+of)\s+(?P<note>{_NOTE_TOKEN})"
    rf"(?:\s+(?P<mode>harmonic minor|melodic minor|major pentatonic|minor pentatonic|"
    rf"whole tone|blues scale|major|minor|maj|min|ionian|aeolian|dorian|phrygian|"
    rf"lydian|mixolydian|locrian|pentatonic))?\b",
    re.IGNORECASE,
)
_BARE_MODE_RE = re.compile(
    r"\b(harmonic minor|melodic minor|major pentatonic|minor pentatonic|whole tone|"
    r"blues scale|dorian|phrygian|lydian|mixolydian|locrian|major|minor)\b",
    re.IGNORECASE,
)
_BPM_RE = re.compile(r"\b(?P<bpm>\d{2,3})\s*(?:bpm|beats per minute)\b", re.IGNORECASE)
_AT_TEMPO_RE = re.compile(r"\bat\s+(?P<bpm>\d{2,3})\b", re.IGNORECASE)
_METER_RE = re.compile(r"\b(?P<num>\d{1,2})\s*/\s*(?P<den>1|2|4|8|16)\b")
_BARS_RE = re.compile(r"\b(?P<bars>\d{1,3})\s*(?:bar|bars|measure|measures)\b", re.IGNORECASE)
_SECONDS_RE = re.compile(r"\b(?P<n>\d{1,3})\s*(?:second|seconds|sec|secs)\b", re.IGNORECASE)
_MINUTES_RE = re.compile(r"\b(?P<n>\d{1,2})\s*(?:minute|minutes|min)\b", re.IGNORECASE)
_SEED_RE = re.compile(r"\bseed\s*[:=]?\s*(?P<seed>\d{1,10})\b", re.IGNORECASE)

_STOPWORDS = {
    "a", "an", "the", "and", "or", "of", "in", "on", "with", "for", "to", "at",
    "some", "make", "create", "generate", "write", "give", "me", "want", "like",
    "something", "that", "is", "it", "sounds", "sound", "sounding", "feel",
    "feels", "vibe", "vibes", "track", "piece", "loop", "idea", "please", "bars",
    "bar", "bpm", "key", "song", "tune", "i", "d", "my", "you", "can", "would",
    "be", "more", "very", "really", "kind", "sort", "bit", "little", "but",
    "then", "into", "over", "as", "its", "this", "playing", "play",
    "piano", "keys", "keyboard", "instrument", "midi", "pattern", "loop",
    "build", "part", "section", "long", "short", "new", "about", "around",
    "one", "two", "four", "eight", "sixteen", "seconds", "minutes", "minute",
    "second", "bpm", "tempo", "time", "signature", "notes", "note",
}


def _pick_weighted(rng: random.Random, weights: dict[str, float], fallback: str) -> str:
    items = [(k, w) for k, w in weights.items() if w > 0]
    if not items:
        return fallback
    total = sum(w for _, w in items)
    roll = rng.random() * total
    for key, weight in items:
        roll -= weight
        if roll <= 0:
            return key
    return items[-1][0]


def _extract_key(text: str) -> tuple[int | None, str | None, str | None]:
    match = _KEY_RE.search(text)
    tonic: int | None = None
    mode: str | None = None
    spelling: str | None = None
    if match:
        raw_note = match.group("note").lower().replace(" ", "")
        raw_note = raw_note.replace("sharp", "#").replace("flat", "b")
        try:
            tonic = parse_note_name(raw_note)
            spelling = raw_note[0].upper() + raw_note[1:]
        except ValueError:
            tonic = None
        if match.group("mode"):
            mode = _MODE_WORDS.get(match.group("mode").lower())
    if mode is None:
        bare = _BARE_MODE_RE.search(text)
        if bare:
            mode = _MODE_WORDS.get(bare.group(1).lower())
    return tonic, mode, spelling


def _extract_tempo(text: str) -> int | None:
    match = _BPM_RE.search(text) or _AT_TEMPO_RE.search(text)
    if match:
        bpm = int(match.group("bpm"))
        if 30 <= bpm <= 240:
            return bpm
    return None


def _extract_meter(text: str) -> tuple[int, int] | None:
    match = _METER_RE.search(text)
    if match:
        num, den = int(match.group("num")), int(match.group("den"))
        if 1 <= num <= 16:
            return (num, den)
    return None


def _leftover_terms(text: str, matched_phrases: list[str],
                    directive_spans: list[str]) -> list[str]:
    words = normalise(text).split()
    consumed: set[str] = set()
    for phrase in matched_phrases:
        consumed.update(phrase.split())
    for span in directive_spans:
        consumed.update(normalise(span).split())
    out: list[str] = []
    for word in words:
        if word in consumed or word in _STOPWORDS or word.isdigit():
            continue
        if re.fullmatch(r"\d+/\d+", word):
            continue
        if word not in out:
            out.append(word)
    return out


def parse_prompt(
    text: str,
    seed: int | None = None,
    vocab: Vocabulary | None = None,
    overrides: dict | None = None,
    corpus=None,
) -> MusicSpec:
    vocab = vocab or load_vocabulary()
    overrides = overrides or {}

    seed_match = _SEED_RE.search(text)
    if seed is None and seed_match:
        seed = int(seed_match.group("seed"))
    if seed is None:
        seed = random.randrange(1, 2**31)
    rng = random.Random(seed)

    matches = vocab.find(text)
    priors = vocab.priors_for(matches)
    if corpus is not None and corpus.entries:
        tags = [m.tag for m in matches]
        priors.progressions.extend(corpus.progressions_for(tags))

    spec = MusicSpec(prompt=text.strip(), seed=seed)
    spec.genres = list(dict.fromkeys(m.tag for m in matches if m.kind == "genre"))
    spec.moods = list(dict.fromkeys(m.tag for m in matches if m.kind == "mood"))
    spec.descriptors = list(dict.fromkeys(
        m.tag for m in matches if m.kind == "descriptor"))
    spec.scales = list(dict.fromkeys(m.tag for m in matches if m.kind == "scale"))
    spec.forms = list(dict.fromkeys(m.tag for m in matches if m.kind == "form"))
    requested_voices = list(dict.fromkeys(m.tag for m in matches if m.kind == "voice"))

    # Naming a form names an era: a fugue is baroque, a sonata is classical.
    for form in spec.forms:
        implied = FORM_IMPLIES_GENRE.get(form)
        if implied and not spec.genres:
            spec.genres = [implied]
            priors = vocab.priors_for(
                matches + [Match("genre", implied, implied, 0, 0)])
    spec.matched_terms = [m.phrase for m in matches]
    directives = [m.group(0) for m in (
        _KEY_RE.search(text), _BARE_MODE_RE.search(text), _BPM_RE.search(text),
        _AT_TEMPO_RE.search(text), _METER_RE.search(text), _BARS_RE.search(text),
        _SECONDS_RE.search(text), _MINUTES_RE.search(text), _SEED_RE.search(text),
    ) if m]
    spec.unmatched_terms = _leftover_terms(text, spec.matched_terms, directives)

    requested_roles = [m.tag for m in matches if m.kind == "role"]

    # --- meter ---
    meter = _extract_meter(text)
    if meter is None:
        meter_name = _pick_weighted(rng, priors.meters, "4/4")
        num, den = meter_name.split("/")
        meter = (int(num), int(den))
    spec.meter = meter

    # --- key ---
    tonic, mode, spelling = _extract_key(text)
    if mode is None or mode not in SCALES:
        mode = _pick_weighted(rng, priors.modes, "major")
    spec.mode = mode
    if tonic is None:
        # Keys that sit well under the hands, weighted toward few accidentals.
        pool = [0, 2, 4, 5, 7, 9, 11, 1, 3, 6, 8, 10]
        weights = [6, 5, 4, 6, 6, 5, 2, 3, 4, 3, 4, 3]
        tonic = rng.choices(pool, weights=weights, k=1)[0]
    spec.tonic = tonic
    spec.tonic_spelling = spelling

    # --- tempo ---
    tempo = _extract_tempo(text)
    if tempo is None:
        low, high = sorted((priors.tempo_low, priors.tempo_high))
        tempo = rng.uniform(low, high) * priors.tempo_scale
    spec.tempo = int(round(tempo))

    # --- length ---
    # A stated bar count is taken literally; everything else lands on the
    # ladder of 4, 8, 16, 32 and 64, because those are the lengths sections
    # actually come in.
    bars_match = _BARS_RE.search(text)
    if bars_match:
        spec.bars = int(bars_match.group("bars"))
    else:
        beats_per_bar = spec.meter[0] * 4.0 / spec.meter[1]
        seconds = None
        if _MINUTES_RE.search(text):
            seconds = int(_MINUTES_RE.search(text).group("n")) * 60
        elif _SECONDS_RE.search(text):
            seconds = int(_SECONDS_RE.search(text).group("n"))
        if seconds:
            spec.bars = snap_to_ladder(int(round(
                seconds * spec.tempo / 60.0 / beats_per_bar)))
        elif spec.scales:
            # "a short drum beat" is eight bars; "symphony orchestra" is
            # sixty-four. The longest thing named wins: an "epic orchestral
            # movement" is a movement, not an epic.
            spec.bars = max(vocab.scales[tag].get("bars", 16) for tag in spec.scales)
        else:
            spec.bars = 16

    # --- content controls ---
    spec.chromaticism = max(0.0, min(1.0, priors.chromaticism))
    spec.ornament = max(0.0, min(1.0, priors.ornament))
    spec.density = priors.density
    spec.swing = priors.swing
    spec.extensions = priors.extensions
    spec.register = int(round(priors.register))
    spec.velocity = int(round(priors.velocity))
    spec.humanize = priors.humanize
    spec.pattern = _pick_weighted(rng, priors.patterns, "block")

    # --- progression ---
    chords, labels = _choose_progression(rng, priors, spec)
    spec.progression = list(chords)
    spec.progression_labels = list(labels)

    # A long progression (a 12-bar blues, say) defines its own phrase length,
    # and overrides the ladder - a blues is twelve bars, not sixteen.
    if not bars_match:
        cycle = len(spec.progression)
        if cycle > 8 and spec.bars % cycle:
            spec.bars = cycle * max(1, round(spec.bars / cycle))

    # --- parts ---
    spec.harmony = _choose_treatment(requested_voices, spec)
    spec.voices = _choose_parts(requested_voices, spec)

    for key, value in overrides.items():
        if value is not None and hasattr(spec, key):
            setattr(spec, key, value)

    return spec.clamp()


# A safe, fully diatonic progression for every mode the generator can pick.
MODE_DEFAULT_PROGRESSIONS = {
    "major": ("I", "V", "vi", "IV"),
    "ionian": ("I", "V", "vi", "IV"),
    "lydian": ("I", "II", "I", "V"),
    "mixolydian": ("I", "bVII", "IV", "I"),
    "major_pentatonic": ("I", "V", "vi", "IV"),
    "whole_tone": ("I", "II", "I", "II"),
    "minor": ("i", "bVI", "bIII", "bVII"),
    "aeolian": ("i", "bVI", "bIII", "bVII"),
    "harmonic_minor": ("i", "iv", "V7", "i"),
    "melodic_minor": ("i", "IV", "V7", "i"),
    "dorian": ("i", "bVII", "IV", "i"),
    "phrygian": ("i", "bII", "bVII", "i"),
    "locrian": ("io", "bVI", "bVII", "io"),
    "minor_pentatonic": ("i", "bVII", "iv", "i"),
    "blues": ("i7", "iv7", "i7", "V7"),
}


# Longest numeral first: with no anchor to force backtracking, an alternation
# that tries "I" before "IV" reads IV7 as a tonic chord and calls the whole
# progression major.
_TONIC_CHORD_RE = re.compile(
    r"^([b#]?)(iii|iv|ii|i|vii|vi|v|III|IV|II|I|VII|VI|V)")


def progression_is_minor(chords: tuple[str, ...] | list[str]) -> bool:
    """Decide a progression's tonality from the quality of its tonic chord.

    'ii7 V7 Imaj7 vi7' is a *major* progression even though it opens on a
    lower-case numeral, so the first symbol alone is not enough.
    """
    for symbol in chords:
        match = _TONIC_CHORD_RE.match(symbol)
        if match and not match.group(1) and match.group(2).upper() == "I":
            return match.group(2).islower()
    return any(symbol.startswith("b") for symbol in chords)


def progression_fit(chords: tuple[str, ...] | list[str], spec: MusicSpec) -> float:
    """Fraction of the progression's chord tones that belong to the key.

    Secondary dominants are exempt: they are deliberately chromatic and are
    idiomatic in exactly the styles that write them.
    """
    allowed = harmonic_pitch_classes(spec.tonic, spec.mode)
    total = fitting = 0
    for symbol in chords:
        if "/" in symbol:
            continue
        try:
            chord = parse_roman(symbol, spec.tonic, spec.mode)
        except ValueError:
            return 0.0
        for pitch_class in chord.pitch_classes:
            total += 1
            fitting += pitch_class in allowed
    return 1.0 if total == 0 else fitting / total


#: How each style realises its harmony part when the prompt does not say.
#: Everything unlisted comps chords.
GENRE_TREATMENT = {
    # The figure is the piece: a repeating cell rather than a chord bed.
    "minimal": "ostinato",
    "techno": "ostinato",
    "cinematic": "ostinato",
    "funk": "ostinato",
    "afrobeat": "ostinato",
    "metal": "ostinato",
    "dubstep": "ostinato",
    "drum_and_bass": "ostinato",
    "trap": "ostinato",
    "boogie_woogie": "ostinato",
    "salsa": "ostinato",
    "prog_rock": "ostinato",
    "house": "ostinato",

    # Broken chords: the harmony arrives one note at a time.
    "chiptune": "arpeggio",
    "trance": "arpeggio",
    "synthwave": "arpeggio",
    "new_age": "arpeggio",
    "impressionist": "arpeggio",
    "lullaby": "arpeggio",
    "bluegrass": "arpeggio",
    "bachata": "arpeggio",
}


def _choose_treatment(requested: list[str], spec: MusicSpec) -> str:
    """How the harmony part is played: comped, repeated or broken."""
    for voice in requested:
        if voice in TREATMENTS:
            return voice
    for genre in spec.genres:
        if genre in GENRE_TREATMENT:
            return GENRE_TREATMENT[genre]
    return "chords"


def _choose_parts(requested: list[str], spec: MusicSpec) -> list[str]:
    """Which of the four parts actually sound.

    All four, unless the prompt narrows the texture on purpose. "just a
    bassline" is one line and is taken at its word; "a countermelody" gets a
    melody to be a counter *to*; anything else alone still gets a bass, so a
    sketch has something underneath it.
    """
    if not requested:
        return list(PARTS)

    parts = [VOICE_PARTS[v] for v in requested if v in VOICE_PARTS]
    if "countermelody" in parts and "melody" not in parts:
        parts.insert(0, "melody")
    if len(parts) == 1 and parts[0] not in ("bass", "harmony"):
        parts.append("bass")
    ordered = [part for part in PARTS if part in parts]
    return ordered or list(PARTS)


def _choose_progression(rng: random.Random, priors, spec: MusicSpec):
    """Write the progression, either from function or from the style's own loops.

    Returns (symbols, labels). The grammar in `middaw.functional` builds a
    progression out of tonic/predominant/dominant motion and can tonicise any
    chord in the key, so it writes progressions that are in no list. Styles
    with a signature loop - a twelve-bar blues, I-V-vi-IV - keep leaning on
    that list, because their identity *is* the loop.
    """
    if rng.random() < priors.functional:
        length = 8 if rng.random() < (0.3 + 0.3 * priors.functional) else 4
        chords = generate_progression(
            tonic=spec.tonic, mode=spec.mode, length=length,
            chromaticism=spec.chromaticism, sevenths=spec.extensions, rng=rng)
        return ([c.symbol for c in chords], [c.display for c in chords])

    chosen = _choose_listed_progression(rng, priors, spec)
    return (list(chosen), list(chosen))


def _choose_listed_progression(rng: random.Random, priors, spec: MusicSpec) -> tuple[str, ...]:
    """Pick a style's stock progression whose tonality agrees with the mode.

    A major-key ii-V-I underneath a natural-minor melody is the single most
    audible way for a generator to sound wrong, so mismatches are all but
    excluded rather than merely discouraged.
    """
    minor_mode = spec.is_minor
    default = MODE_DEFAULT_PROGRESSIONS.get(
        spec.mode, ("i", "bVI", "bIII", "bVII") if minor_mode else ("I", "V", "vi", "IV"))

    # A twelve-bar is I7-IV7-V7 whether or not the tune over it is bluesy, so
    # the blues scales accept either tonality; every other mode must agree.
    ambivalent = spec.mode in BLUES_MODES
    candidates = [(chords, weight) for chords, weight in priors.progressions
                  if weight > 0
                  and (ambivalent or progression_is_minor(chords) == minor_mode)]
    # The mode's own default is always in the running, and is always fully
    # diatonic, so the fully-diatonic tier below is never empty.
    candidates.append((default, 1.0))

    # Prefer progressions that are fully diatonic to the chosen mode; a
    # bVI under a dorian melody is the kind of clash that makes generated
    # music sound like it was assembled rather than written.
    scored = [(chords, weight, progression_fit(chords, spec)) for chords, weight in candidates]
    for threshold in (0.999, 0.85):
        tier = [(c, w) for c, w, fit in scored if fit >= threshold]
        if tier:
            candidates = tier
            break
    else:
        return default

    total = sum(w for _, w in candidates)
    roll = rng.random() * total
    for chords, weight in candidates:
        roll -= weight
        if roll <= 0:
            return chords
    return candidates[-1][0]
