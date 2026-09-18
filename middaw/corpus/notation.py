"""Readers for notated music: MusicXML and RomanText.

Middaw writes MIDI, but MIDI is a poor thing to *measure* against. It has no
barlines, no key signature you can trust, no separated voices and no idea which
note the analyst thought was the chord. Notation keeps all of that, which is
why the measuring harness reads scores rather than sequences.

Both formats are read here with the standard library only, for the same reason
`middaw/midi.py` writes MIDI by hand: the file formats are the premise of the
project and should be inspectable. MusicXML is XML in a zip; RomanText is
lines of text. Neither needs a dependency.
"""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET
import zipfile
from dataclasses import dataclass, field
from pathlib import Path

from middaw.song import Note
from middaw.theory import NOTE_NAMES

STEP_PITCH_CLASSES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

#: Major key for each number of sharps (positive) or flats (negative).
FIFTHS_TONIC = {0: 0, 1: 7, 2: 2, 3: 9, 4: 4, 5: 11, 6: 6, 7: 1,
                -1: 5, -2: 10, -3: 3, -4: 8, -5: 1, -6: 6, -7: 11}


@dataclass
class Score:
    """A notated piece, flattened into the same note list the generator uses."""

    notes: list[Note] = field(default_factory=list)
    parts: dict[str, list[Note]] = field(default_factory=dict)
    meter: tuple[int, int] = (4, 4)
    tempo: float = 90.0
    tonic: int = 0                       # from the key signature
    mode: str = "major"
    #: Whether the file actually *said* major or minor. A key signature alone
    #: names a collection, not a key: two sharps is D major and B minor and
    #: E dorian. MuseScore's MusicXML export writes no <mode> element at all,
    #: so assuming major there invents a ground truth and then marks correct
    #: answers wrong against it.
    key_stated: bool = False
    #: The major key the signature names, whatever the actual key is.
    signature_tonic: int = 0
    #: Written measure number -> beat it starts on. A pickup bar is usually
    #: numbered 0, and the analyses number their measures the same way, which
    #: is what lets the two be lined up.
    measure_starts: dict[int, float] = field(default_factory=dict)
    #: How long each written measure actually is, which is how a pickup is
    #: recognised.
    measure_lengths: dict[int, float] = field(default_factory=dict)

    @property
    def beats_per_bar(self) -> float:
        return self.meter[0] * 4.0 / self.meter[1]

    @property
    def key_name(self) -> str:
        return f"{NOTE_NAMES[self.tonic]} {self.mode}"

    def measure_beat(self, measure: int, beat: float = 1.0) -> float | None:
        """Where "m12 b3" falls, in beats from the start.

        A pickup bar is short, and its beats are the *last* beats of a nominal
        bar: "m0 b4" in four-four is the only beat a one-beat pickup has, and
        it starts the piece. Counting from the front of a pickup puts every
        chord in it three beats late.
        """
        start = self.measure_starts.get(measure)
        if start is None:
            return None
        offset = 0.0
        if self.measure_starts and measure == min(self.measure_starts):
            length = self.measure_lengths.get(measure, self.beats_per_bar)
            offset = max(0.0, self.beats_per_bar - length)
        return start + (beat - 1.0) - offset


def _text(element, tag, default=None):
    found = element.find(tag)
    return found.text if found is not None and found.text else default


def read_musicxml(path) -> Score:
    """Parse a MusicXML file (.xml, .musicxml, or zipped .mxl)."""
    path = Path(path)
    if path.suffix.lower() == ".mxl":
        with zipfile.ZipFile(path) as archive:
            inner = [n for n in archive.namelist()
                     if not n.startswith("META-INF") and n.lower().endswith(
                         (".xml", ".musicxml"))]
            if not inner:
                raise ValueError(f"{path.name}: no score inside the archive")
            root = ET.fromstring(archive.read(inner[0]))
    else:
        root = ET.parse(path).getroot()

    if root.tag != "score-partwise":
        raise ValueError(f"{path.name}: only score-partwise is supported")

    score = Score()
    names = {p.get("id"): (_text(p, "part-name") or p.get("id"))
             for p in root.iterfind("./part-list/score-part")}
    _read_key(root, score)

    for part in root.iterfind("part"):
        part_name = names.get(part.get("id"), part.get("id") or "Part")
        notes = _read_part(part, score)
        score.parts.setdefault(part_name, []).extend(notes)
        score.notes.extend(notes)

    score.notes.sort(key=lambda n: (n.start, n.pitch))
    return score


def _read_key(root, score: Score) -> None:
    """Take the key from the first part that states one, and stop.

    The parts of one score can disagree: in 156 of the 410 Bach chorales the
    soprano is marked minor and the lower three major, all with the same
    signature. Reading every part and letting the last win calls a third of
    the collection major that is not. The first statement is the one the
    encoder meant.
    """
    key = root.find("./part/measure/attributes/key")
    if key is None:
        return
    fifths = int(_text(key, "fifths", 0))
    stated = _text(key, "mode")
    mode = (stated or "major").lower()
    tonic = FIFTHS_TONIC.get(fifths, 0)
    score.signature_tonic = tonic
    score.key_stated = bool(stated) and mode in ("major", "minor")
    if mode.startswith("minor"):
        score.tonic = (tonic + 9) % 12
        score.mode = "minor"
    else:
        score.tonic = tonic
        score.mode = "major" if mode == "major" else mode


def _read_part(part, score: Score) -> list[Note]:
    """One part's notes, in beats from the start of the piece."""
    notes: list[Note] = []
    divisions = 1.0
    cursor = 0.0
    previous_onset = 0.0
    # A tie is written on both notes; the sounding note is one note.
    open_ties: dict[tuple[str, int], Note] = {}

    for measure in part.iterfind("measure"):
        number = measure.get("number")
        written = None
        if number is not None:
            try:
                written = int(number)
            except ValueError:
                written = None
            if written is not None:
                score.measure_starts.setdefault(written, round(cursor, 6))
        measure_began = cursor

        for element in measure:
            if element.tag == "attributes":
                divisions = float(_text(element, "divisions", divisions))
                time = element.find("time")
                if time is not None:
                    beats = _text(time, "beats")
                    beat_type = _text(time, "beat-type")
                    try:
                        # "3+2/8" and "(6)/8" are both written in the wild; a
                        # meter we cannot read is not a reason to lose a score.
                        score.meter = (int(beats), int(beat_type))
                    except (TypeError, ValueError):
                        pass
            elif element.tag == "sound" and element.get("tempo"):
                score.tempo = float(element.get("tempo"))
            elif element.tag == "backup":
                cursor -= float(_text(element, "duration", 0)) / divisions
            elif element.tag == "forward":
                cursor += float(_text(element, "duration", 0)) / divisions
            elif element.tag == "note":
                cursor, previous_onset = _read_note(
                    element, notes, divisions, cursor, previous_onset, open_ties)

        if written is not None:
            score.measure_lengths.setdefault(
                written, round(cursor - measure_began, 6))

    return notes


def _read_note(element, notes, divisions, cursor, previous_onset, open_ties):
    """Add one note and return the new (cursor, previous onset)."""
    if element.find("grace") is not None:
        return cursor, previous_onset          # no written duration to place

    length = float(_text(element, "duration", 0)) / divisions
    is_chord = element.find("chord") is not None
    start = previous_onset if is_chord else cursor

    pitch = element.find("pitch")
    if pitch is None:                          # a rest
        return (cursor if is_chord else cursor + length), start

    step = _text(pitch, "step", "C")
    alter = int(float(_text(pitch, "alter", 0)))
    octave = int(_text(pitch, "octave", 4))
    midi = (octave + 1) * 12 + STEP_PITCH_CLASSES.get(step, 0) + alter

    voice = _text(element, "voice", "1")
    tie_types = {t.get("type") for t in element.findall("tie")}
    key = (voice, midi)

    held = open_ties.get(key)
    if held is not None and "stop" in tie_types:
        held.duration = round(start + length - held.start, 6)
        if "start" not in tie_types:
            open_ties.pop(key, None)
    else:
        note = Note(start=round(start, 6), duration=round(length, 6),
                    pitch=max(0, min(127, midi)), velocity=80)
        notes.append(note)
        if "start" in tie_types:
            open_ties[key] = note

    return (cursor if is_chord else cursor + length), start


# --------------------------------------------------------------------------
# Humdrum **kern: the other format the good encodings come in.
# --------------------------------------------------------------------------

_KERN_DURATION_RE = re.compile(r"(\d+)(\.*)")
_KERN_PITCH_RE = re.compile(r"([a-gA-G]+)([#\-n]*)")


def kern_pitch(token: str) -> int | None:
    """'cc#' -> 73. Lower case is middle C up; upper case is below it."""
    match = _KERN_PITCH_RE.search(token)
    if not match:
        return None
    letters, accidentals = match.groups()
    letter = letters[0]
    if letter.islower():
        octave = 4 + len(letters) - 1
    else:
        octave = 3 - (len(letters) - 1)
    pitch = (octave + 1) * 12 + STEP_PITCH_CLASSES[letter.upper()]
    pitch += accidentals.count("#") - accidentals.count("-")
    return pitch


def kern_duration(token: str) -> float | None:
    """'4.' -> 1.5 beats. The number is a division of a whole note."""
    # Not anchored: a token can open with a tie or a phrase mark - "[2a" is a
    # half note that happens to start a tie, and matching from the front reads
    # it as no duration at all and silently drops every tied note in the file.
    match = _KERN_DURATION_RE.search(token)
    if not match:
        return None
    value, dots = match.groups()
    number = int(value)
    length = 8.0 if number == 0 else 4.0 / number
    return length * (2.0 - 0.5 ** len(dots))


def read_kern(path) -> Score:
    """Parse a Humdrum `**kern` file.

    Each spine keeps its own clock: a data token places a note and moves that
    spine forward, and a null token (`.`) means the note before it is still
    sounding. That is what keeps the parts aligned without a bar count.
    """
    score = Score(tempo=90.0)
    spines: list[int] = []          # indices of the **kern columns
    names: dict[int, str] = {}
    clocks: dict[int, float] = {}
    open_ties: dict[tuple[int, int], Note] = {}
    measure = 0

    for line in Path(path).read_text(encoding="utf-8", errors="replace").splitlines():
        if not line or line.startswith("!"):
            continue
        columns = line.split("\t")

        if line.startswith("**"):
            spines = [i for i, c in enumerate(columns) if c == "**kern"]
            clocks = {i: 0.0 for i in spines}
            continue
        if line.startswith("*"):
            for index in spines:
                if index >= len(columns):
                    continue
                token = columns[index]
                if token.startswith('*I"'):
                    names[index] = token[3:].strip() or f"Part {index}"
                elif token.startswith("*M") and "/" in token:
                    top, _, bottom = token[2:].partition("/")
                    if top.isdigit() and bottom.split()[0].isdigit():
                        score.meter = (int(top), int(bottom.split()[0]))
                elif token.startswith("*MM") and token[3:].replace(".", "").isdigit():
                    score.tempo = float(token[3:])
                elif token.endswith(":") and len(token) > 1:
                    parsed = parse_romantext_key(token[1:-1])
                    if parsed:
                        score.tonic, score.mode = parsed
                        score.key_stated = True
                        score.signature_tonic = (
                            parsed[0] if parsed[1] == "major"
                            else (parsed[0] + 3) % 12)
            continue
        if line.startswith("="):
            number = re.match(r"=+(\d+)", columns[0])
            if number:
                measure = int(number.group(1))
                start = min((clocks[i] for i in spines if i in clocks), default=0.0)
                score.measure_starts.setdefault(measure, round(start, 6))
                if measure - 1 in score.measure_starts:
                    score.measure_lengths.setdefault(
                        measure - 1,
                        round(start - score.measure_starts[measure - 1], 6))
            continue

        for index in spines:
            if index >= len(columns):
                continue
            token = columns[index].strip()
            if not token or token == "." or "q" in token.lower():
                continue                      # null token, or a grace note
            length = kern_duration(token)
            if length is None:
                continue
            start = clocks[index]
            clocks[index] = start + length
            if "r" in token.split()[0] and not _KERN_PITCH_RE.search(token.split()[0]):
                continue                      # a rest still takes its time
            part = names.get(index, f"Part {index + 1}")
            for chord_note in token.split():
                if "r" in chord_note and not _KERN_PITCH_RE.search(chord_note):
                    continue
                pitch = kern_pitch(chord_note)
                if pitch is None:
                    continue
                key = (index, pitch)
                held = open_ties.get(key)
                if held is not None and ("]" in chord_note or "_" in chord_note):
                    held.duration = round(start + length - held.start, 6)
                    if "_" not in chord_note:
                        open_ties.pop(key, None)
                    continue
                note = Note(start=round(start, 6), duration=round(length, 6),
                            pitch=max(0, min(127, pitch)), velocity=80)
                score.parts.setdefault(part, []).append(note)
                score.notes.append(note)
                if "[" in chord_note or "_" in chord_note:
                    open_ties[key] = note

    score.notes.sort(key=lambda n: (n.start, n.pitch))
    return score


def read_score(path) -> Score:
    """Read whichever notation format this file is in."""
    suffix = Path(path).suffix.lower()
    if suffix in (".krn", ".kern"):
        return read_kern(path)
    return read_musicxml(path)


# --------------------------------------------------------------------------
# RomanText: a human analyst's reading of the same music.
# --------------------------------------------------------------------------

@dataclass
class AnalysedChord:
    measure: int
    beat: float
    numeral: str
    key: str            # as written: upper case major, lower case minor


@dataclass
class Analysis:
    chords: list[AnalysedChord] = field(default_factory=list)
    headers: dict[str, str] = field(default_factory=dict)
    meter: tuple[int, int] | None = None
    skipped: int = 0    # lines a fuller reader would understand

    @property
    def key(self) -> str:
        return self.chords[0].key if self.chords else ""

    def tonic_and_mode(self) -> tuple[int, str] | None:
        return parse_romantext_key(self.key) if self.chords else None


_HEADER_RE = re.compile(r"^([A-Za-z ]+):\s*(.*)$")
_MEASURE_RE = re.compile(r"^m(\d+)(?:-\d+)?\b")
_BEAT_RE = re.compile(r"^b(\d+(?:\.\d+)?)$")
_KEY_RE = re.compile(r"^([a-gA-G][#b-]*):$")
# Everything a numeral may carry: an accidental, the numeral, a quality mark,
# figured-bass digits, and a tonicised chord after a slash.
_NUMERAL_RE = re.compile(
    r"^[b#-]*(?:[ivIV]+)(?:o|\+|ø|%|d|h)?(?:\d+(?:/\d+)?)*"
    r"(?:/[b#-]*[ivIV]+(?:o|\+|ø|%)?\d*)*$")


def parse_romantext_key(written: str) -> tuple[int, str] | None:
    """'G' -> (7, 'major'); 'bb' -> (10, 'minor')."""
    match = re.match(r"^([a-gA-G])([#b-]*)$", written or "")
    if not match:
        return None
    letter, accidentals = match.groups()
    pitch = STEP_PITCH_CLASSES[letter.upper()]
    pitch += accidentals.count("#") - accidentals.count("b") - accidentals.count("-")
    mode = "major" if letter.isupper() else "minor"
    return pitch % 12, mode


def read_romantext(path) -> Analysis:
    """Parse the common subset of RomanText: headers, measures, keys, numerals.

    Variant readings (`m14var1`) and copied measures (`m5 = m1`) are counted
    rather than expanded, so the report can say what it did not read instead of
    quietly measuring against less than the analyst wrote.
    """
    analysis = Analysis()
    current_key = ""

    for raw in Path(path).read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("//"):
            continue

        measure_match = _MEASURE_RE.match(line)
        if not measure_match:
            header = _HEADER_RE.match(line)
            if header:
                name, value = header.group(1).strip(), header.group(2).strip()
                analysis.headers[name] = value
                if name == "Time Signature" and "/" in value:
                    top, bottom = value.split("/")[:2]
                    if top.isdigit() and bottom.isdigit():
                        analysis.meter = (int(top), int(bottom))
            elif line.startswith("m"):
                analysis.skipped += 1
            continue

        if "var" in line.split()[0] or "=" in line:
            analysis.skipped += 1
            continue

        measure = int(measure_match.group(1))
        beat = 1.0
        for token in line[measure_match.end():].split():
            if token in ("|", "||", "|:", ":|", "||:"):
                continue
            beat_match = _BEAT_RE.match(token)
            if beat_match:
                beat = float(beat_match.group(1))
                continue
            key_match = _KEY_RE.match(token)
            if key_match:
                current_key = key_match.group(1)
                continue
            if _NUMERAL_RE.match(token):
                analysis.chords.append(
                    AnalysedChord(measure=measure, beat=beat,
                                  numeral=token, key=current_key))
            else:
                analysis.skipped += 1

    return analysis
