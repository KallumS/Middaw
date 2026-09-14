"""Spec -> `Song` -> MIDI bytes."""

from __future__ import annotations

import random
import re
from dataclasses import dataclass

from middaw.accompaniment import generate_accompaniment, generate_bass
from middaw.melody import DEFAULT_INTERVALS, generate_melody
from middaw.midi import song_to_bytes
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

    def to_dict(self) -> dict:
        return {"spec": self.spec.to_dict(), "song": self.song.to_dict(),
                "chords": self.chords}


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


def name_chords(spec: MusicSpec, spans) -> list[dict]:
    """Name each bar's harmony with the ScaleView chord reader.

    The symbol is read back off the notes rather than taken from the roman
    numeral that produced them, so what the user is shown is what is actually
    in the MIDI - and it is the same routine the corpus labeller uses.
    """
    key = spec.key()
    out = []
    for bar, (start, _length, chord) in enumerate(spans):
        out.append({
            "bar": bar + 1,
            "beat": round(start, 4),
            "roman": chord.symbol,
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
    spans = build_chord_spans(spec, rng)

    song = Song(tempo=spec.tempo, meter=spec.meter,
                ticks_per_beat=spec.ticks_per_beat, key_name=spec.key_name)

    if "chords" in spec.roles:
        chord_notes = generate_accompaniment(spec, spans, rng)
        song.tracks.append(Track(name="Chords", program=ACOUSTIC_GRAND_PIANO,
                                 channel=0, notes=chord_notes))
    if "melody" in spec.roles:
        melody_notes = generate_melody(spec, _chords_by_bar(spans), rng,
                                       intervals=intervals,
                                       rhythm_bias=rhythm_bias)
        song.tracks.append(Track(name="Melody", program=ACOUSTIC_GRAND_PIANO,
                                 channel=1, notes=melody_notes))
    if "bass" in spec.roles:
        bass_notes = generate_bass(spec, spans, rng)
        song.tracks.append(Track(name="Bass", program=ACOUSTIC_GRAND_PIANO,
                                 channel=2, notes=bass_notes))

    for track in song.tracks:
        _humanize_timing(spec, track.notes, rng)
        _dynamic_arc(spec, track.notes)
        _trim_overlaps(track.notes)
        track.notes.sort(key=lambda n: (n.start, n.pitch))

    return Generation(spec=spec, song=song, midi=song_to_bytes(song),
                      chords=name_chords(spec, spans))


def generate(prompt: str, seed: int | None = None, **overrides) -> Generation:
    """Convenience end-to-end entry point: text in, MIDI out."""
    from middaw.prompt import parse_prompt

    spec = parse_prompt(prompt, seed=seed, overrides=overrides or None)
    return render(spec)
