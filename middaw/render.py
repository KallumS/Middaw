"""Spec -> `Song` -> MIDI bytes."""

from __future__ import annotations

import random
import re
from dataclasses import dataclass

from dataclasses import replace

from middaw.accompaniment import generate_accompaniment, generate_bass
from middaw.form import Section, choose_form, describe, plan_form
from middaw.functional import generate_progression, recadence
from middaw.melody import DEFAULT_INTERVALS, generate_melody
from middaw.midi import song_to_bytes
from middaw.voices import (generate_arpeggio, generate_countermelody,
                           generate_ostinato, make_ostinato_figure)
from middaw.song import Note, Song, Track
from middaw.spec import MusicSpec
from middaw.scaleview import detect_chord
from middaw.theory import Chord, parse_roman

_SUFFIXED = re.compile(r"(maj7|maj9|add9|sus2|sus4|m7|o7|[679]|o|0|\+)$")

ACOUSTIC_GRAND_PIANO = 0


@dataclass
class Generation:
    spec: MusicSpec
    song: Song
    midi: bytes
    chords: list[dict]
    sections: list[Section] = None

    def to_dict(self) -> dict:
        return {"spec": self.spec.to_dict(), "song": self.song.to_dict(),
                "chords": self.chords,
                "sections": [s.to_dict() for s in (self.sections or [])]}


def _colour(symbol: str, rng: random.Random, extensions: float) -> str:
    """Optionally upgrade a plain triad to a seventh, per the style's taste."""
    if _SUFFIXED.search(symbol) or rng.random() > extensions:
        return symbol
    accidental = symbol[0] if symbol[0] in "b#" else ""
    numeral = symbol[len(accidental):]
    if numeral.isupper():
        return symbol + ("7" if numeral in ("V",) else "maj7")
    return symbol + "7"


def build_chord_spans(spec: MusicSpec, rng: random.Random) -> list[tuple[float, float, Chord]]:
    """Lay the progression out across the bars, one chord per bar."""
    beats_per_bar = spec.beats_per_bar
    spans: list[tuple[float, float, Chord]] = []
    coloured = [_colour(sym, rng, spec.extensions) for sym in spec.progression]
    for bar in range(spec.bars):
        symbol = coloured[bar % len(coloured)]
        try:
            chord = parse_roman(symbol, spec.tonic, spec.mode)
        except ValueError:
            chord = parse_roman(spec.progression[bar % len(spec.progression)],
                                spec.tonic, spec.mode)
        spans.append((bar * beats_per_bar, beats_per_bar, chord))
    return spans


def _chords_by_bar(spans) -> list[list[tuple[float, Chord]]]:
    return [[(0.0, chord)] for _start, _length, chord in spans]


def name_chords(spec: MusicSpec, spans, labels=None) -> list[dict]:
    """Name each bar's harmony with the ScaleView chord reader.

    The symbol is read back off the notes rather than taken from the roman
    numeral that produced them, so what the user is shown is what is actually
    in the MIDI - and it is the same routine the corpus labeller uses.
    """
    key = spec.key()
    labels = labels or spec.progression_labels or spec.progression
    out = []
    for bar, (start, _length, chord) in enumerate(spans):
        out.append({
            "bar": bar + 1,
            "beat": round(start, 4),
            "roman": chord.symbol,
            # What the chord is *doing* - "V7/vi", "SubV7", "ii/IV" - which is
            # the thing a musician wants to see, not the raw numeral.
            "function": labels[bar % len(labels)] if labels else chord.symbol,
            "symbol": detect_chord(chord.pitch_classes, chord.bass, key) or "",
        })
    return out


def _dynamic_arc(spec: MusicSpec, notes: list[Note]) -> None:
    """A gentle swell across the piece, plus a softer first phrase."""
    if not notes:
        return
    total = max(n.end for n in notes)
    if total <= 0:
        return
    for note in notes:
        position = note.start / total
        swell = int(round(10 * (position - 0.5) * 2 * 0.5))
        intro = -8 if position < 0.12 else 0
        outro = -6 if position > 0.92 else 0
        note.velocity = max(1, min(127, note.velocity + swell + intro + outro))


def _humanize_timing(spec: MusicSpec, notes: list[Note], rng: random.Random) -> None:
    jitter = 0.012 * spec.humanize
    if jitter <= 0:
        return
    for note in notes:
        note.start = max(0.0, note.start + rng.gauss(0, jitter))


def _trim_overlaps(notes: list[Note]) -> None:
    """Stop a repeated pitch from being cut short by its own predecessor."""
    by_pitch: dict[int, Note] = {}
    for note in sorted(notes, key=lambda n: n.start):
        previous = by_pitch.get(note.pitch)
        if previous and previous.end > note.start:
            previous.duration = max(0.05, note.start - previous.start - 0.01)
        by_pitch[note.pitch] = note


def render(spec: MusicSpec, rng: random.Random | None = None,
           priors=None) -> Generation:
    """Render a spec. `priors` is an optional `CorpusPriors`; without one the
    generator uses its built-in musical defaults, which is the day-one case."""
    rng = rng or random.Random(spec.seed)
    tags = spec.genres + spec.moods + spec.descriptors
    intervals = dict(DEFAULT_INTERVALS)
    rhythm_bias = None
    if priors is not None and priors.entries:
        intervals = priors.intervals_for(tags, DEFAULT_INTERVALS)
        rhythm_bias = priors.rhythm_bias_for(tags)
        spec.corpus_sources = priors.sources_for(tags)

    def fresh_progression(length: int, cadence: str | None = None, base=None):
        if base is not None and cadence:
            # Same section, different ending.
            return recadence(base[0], base[1], spec.tonic, spec.mode, cadence,
                             sevenths=any("7" in sym for sym in base[0]))
        chords = generate_progression(
            tonic=spec.tonic, mode=spec.mode, length=length,
            chromaticism=spec.chromaticism, sevenths=spec.extensions, rng=rng,
            cadence=cadence)
        return ([c.symbol for c in chords], [c.display for c in chords])

    spec.form_name = choose_form(spec, random.Random(spec.seed))
    spec.forms = [spec.form_name]
    sections = plan_form(spec, rng, make_progression=fresh_progression)
    spec.form = describe(sections)
    spec.bars = sum(section.bars for section in sections)

    song = Song(tempo=spec.tempo, meter=spec.meter,
                ticks_per_beat=spec.ticks_per_beat, key_name=spec.key_name)
    voices = spec.voices or spec.roles or ["melody", "chords", "bass"]
    names = {"melody": "Melody", "countermelody": "Countermelody",
             "ostinato": "Ostinato", "arpeggio": "Arpeggio",
             "chords": "Chords", "bass": "Bass"}
    tracks = {voice: Track(name=names[voice], program=ACOUSTIC_GRAND_PIANO,
                           channel=index)
              for index, voice in enumerate(v for v in names if v in voices)}

    # An ostinato is one figure restated; it is invented once for the piece,
    # not once per section, or it stops being an ostinato.
    ostinato_figure = (make_ostinato_figure(spec, random.Random(spec.seed ^ 0x05713))
                       if "ostinato" in tracks else None)

    beats_per_bar = spec.beats_per_bar
    all_spans: list[tuple[float, float, Chord]] = []
    all_labels: list[str] = []

    for section in sections:
        # Each section is rendered as its own little piece, then slid into
        # place. Sections that share a letter share a motif, so the return of
        # A is heard as a return.
        part = replace(spec, bars=section.bars, density=section.density,
                       register=section.register, velocity=section.velocity,
                       pattern=section.pattern,
                       progression=list(section.progression),
                       progression_labels=list(section.progression_labels)).clamp()
        motif_rng = random.Random(f"{spec.seed}:{section.letter}")
        spans = build_chord_spans(part, rng)
        offset = section.start_bar * beats_per_bar

        melody: list[Note] = []
        if "melody" in tracks:
            melody = generate_melody(part, _chords_by_bar(spans), rng,
                                     intervals=intervals, rhythm_bias=rhythm_bias,
                                     motif_rng=motif_rng, cadence=section.cadence)
        if "countermelody" in tracks:
            # Set against whatever the melody is doing, even when there is no
            # melody track: then it is simply the only line.
            against = melody or generate_melody(
                part, _chords_by_bar(spans), random.Random(spec.seed),
                intervals=intervals, motif_rng=motif_rng, cadence=section.cadence)
            _extend(tracks["countermelody"],
                    generate_countermelody(part, spans, against, rng), offset)
        if "melody" in tracks:
            _extend(tracks["melody"], melody, offset, section.transpose)
        if "ostinato" in tracks:
            _extend(tracks["ostinato"],
                    generate_ostinato(part, spans, rng, ostinato_figure), offset)
        if "arpeggio" in tracks:
            _extend(tracks["arpeggio"], generate_arpeggio(part, spans, rng), offset)
        if "chords" in tracks:
            _extend(tracks["chords"], generate_accompaniment(part, spans, rng), offset)
        if "bass" in tracks:
            _extend(tracks["bass"], generate_bass(part, spans, rng), offset)

        all_spans += [(start + offset, length, chord) for start, length, chord in spans]
        all_labels += [section.progression_labels[i % len(section.progression_labels)]
                       for i in range(section.bars)]

    song.tracks = [track for track in tracks.values() if track.notes]

    for track in song.tracks:
        _humanize_timing(spec, track.notes, rng)
        _dynamic_arc(spec, track.notes)
        _trim_overlaps(track.notes)
        track.notes.sort(key=lambda n: (n.start, n.pitch))

    return Generation(spec=spec, song=song, midi=song_to_bytes(song),
                      chords=name_chords(spec, all_spans, all_labels),
                      sections=sections)


def _extend(track: Track, notes: list[Note], offset: float,
            transpose: int = 0) -> None:
    for note in notes:
        note.start += offset
        if transpose:
            note.pitch = max(21, min(108, note.pitch + transpose))
        track.notes.append(note)


def generate(prompt: str, seed: int | None = None, **overrides) -> Generation:
    """Convenience end-to-end entry point: text in, MIDI out."""
    from middaw.prompt import parse_prompt

    spec = parse_prompt(prompt, seed=seed, overrides=overrides or None)
    return render(spec)
