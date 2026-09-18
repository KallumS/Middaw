"""Non-chord tones - the notes that decorate the harmony rather than belong to it.

Middaw writes a skeleton of chord tones and then embellishes it. That order is
deliberate: a non-chord tone is not a kind of pitch, it is a *relationship*.
Hutchinson classifies all nine by how the note is approached and how it is left,
and nothing about the note itself tells you which one it is:

| Type | Approached by | Left by | Accent |
| --- | --- | --- | --- |
| Passing tone | step | step, same direction | unaccented |
| Neighbor tone | step | step, opposite direction | unaccented |
| Appoggiatura | leap | step | accented |
| Escape tone | step | leap, opposite direction | unaccented |
| Anticipation | step | the same note | unaccented |
| Suspension | the same note | step **down** | accented |
| Retardation | the same note | step **up** | accented |

So they can only be added once the skeleton exists, and each one is *checked*
against its own definition after it is built - `_classify` re-derives the type
from the approach and departure and the device is discarded if it does not come
out as the one intended. That makes the module self-verifying: it cannot claim
to have written a passing tone and have written something else.

Two mechanisms produce all of them:

* **Splitting** a skeleton note in two, the inserted note taking the first half
  (accented - appoggiatura) or the second (unaccented - passing, neighbor,
  escape).
* **Moving a boundary** at a chord change: holding a note through it so it
  becomes dissonant and then resolving by step (suspension, retardation), or
  arriving at the next note early (anticipation).

Every added pitch is a scale degree, so embellishment never takes the melody
out of the key.
"""

from __future__ import annotations

import random
from dataclasses import dataclass

from middaw.song import Note
from middaw.spec import MusicSpec
from middaw.theory import Chord, degree_to_pitch, nearest_degree, scale_pitch_classes

PASSING = "passing"
NEIGHBOR = "neighbor"
APPOGGIATURA = "appoggiatura"
ESCAPE = "escape"
ANTICIPATION = "anticipation"
SUSPENSION = "suspension"
RETARDATION = "retardation"

#: A leap is anything wider than a step. Two semitones is still a step - a
#: major second - so the boundary sits at three.
LEAP = 3


#: How often each device is reached for. Passing tones and neighbors are the
#: common currency of embellishment; an appoggiatura is an event.
WEIGHTS = {PASSING: 4.0, NEIGHBOR: 3.0, ESCAPE: 1.5, APPOGGIATURA: 1.2}


@dataclass(frozen=True)
class Embellishment:
    kind: str
    beat: float
    pitch: int

    def to_dict(self) -> dict:
        return {"kind": self.kind, "beat": round(self.beat, 4), "pitch": self.pitch}


def _classify(approach: int | None, departure: int | None) -> str | None:
    """Name the device from how the note is approached and left.

    This is the definition, applied literally, and it is what every device is
    checked against before it is accepted.
    """
    if approach is None or departure is None:
        return None
    if approach == 0:
        if departure < 0 and abs(departure) < LEAP:
            return SUSPENSION
        if departure > 0 and abs(departure) < LEAP:
            return RETARDATION
        return None
    if departure == 0:
        return ANTICIPATION if abs(approach) < LEAP else None

    stepped_in = abs(approach) < LEAP
    stepped_out = abs(departure) < LEAP
    same_direction = approach * departure > 0

    if stepped_in and stepped_out:
        return PASSING if same_direction else NEIGHBOR
    if not stepped_in and stepped_out:
        return APPOGGIATURA
    if stepped_in and not stepped_out and not same_direction:
        return ESCAPE
    return None


class _Key:
    """Scale-degree arithmetic anchored low enough to cover the whole keyboard."""

    def __init__(self, spec: MusicSpec):
        self.scale = scale_pitch_classes(spec.tonic, spec.mode)
        self.root = 48 + (spec.tonic % 12)

    def degree(self, pitch: int) -> int:
        return nearest_degree(self.scale, self.root, pitch)

    def pitch(self, degree: int) -> int:
        return degree_to_pitch(self.scale, self.root, degree)

    def step(self, pitch: int, direction: int) -> int:
        return self.pitch(self.degree(pitch) + direction)


def _chord_at(spans: list[tuple[float, float, Chord]], beat: float) -> Chord | None:
    for start, length, chord in spans:
        if start - 1e-6 <= beat < start + length - 1e-6:
            return chord
    return spans[-1][2] if spans else None


def _is_chord_tone(spans, beat: float, pitch: int) -> bool:
    chord = _chord_at(spans, beat)
    return chord is not None and pitch % 12 in chord.pitch_classes


def embellish(spec: MusicSpec, spans: list[tuple[float, float, Chord]],
              notes: list[Note], rng: random.Random,
              amount: float | None = None,
              protect_last: bool = True) -> tuple[list[Note], list[Embellishment]]:
    """Decorate a chord-tone line with non-chord tones.

    `amount` is the chance of taking each opportunity. The last note is left
    alone by default: it is the cadence, and a cadence is not a place for
    decoration.
    """
    if len(notes) < 2 or not spans:
        return notes, []
    amount = spec.ornament if amount is None else amount
    if amount <= 0:
        return notes, []

    key = _Key(spec)
    line = sorted((Note(n.start, n.duration, n.pitch, n.velocity) for n in notes),
                  key=lambda n: n.start)
    applied: list[Embellishment] = []
    pulse = max(0.25, spec.beats_per_bar / max(1, spec.meter[0]))
    minimum = max(0.11, pulse / 4)
    last_index = len(line) - 1 if protect_last else len(line)

    # Boundary devices first: they move note starts and ends, and doing them
    # after the splits would mean operating on halves of notes.
    line, applied, frozen = _boundary_pass(spec, spans, key, line, rng, amount,
                                           minimum, last_index, applied)
    line, applied = _split_pass(spec, spans, key, line, rng, amount,
                                minimum, applied, frozen)

    line.sort(key=lambda n: (n.start, n.pitch))
    line = _monophonic(line, minimum)
    return line, _verify(spans, line, applied)


def _monophonic(line: list[Note], minimum: float) -> list[Note]:
    """One voice, one note at a time.

    Holding a note across a chord change can leave it sounding under the notes
    that follow. A melodic line is a single voice, so a note stops when the
    next one starts - and that also makes "the note it resolves to"
    unambiguous, which is what the classification depends on.
    """
    out: list[Note] = []
    for index, note in enumerate(line):
        if index + 1 < len(line):
            room = line[index + 1].start - note.start
            if room <= 0:
                continue                  # two notes on the same onset: keep one
            note.duration = min(note.duration, room)
        if note.duration >= minimum * 0.5:
            out.append(note)
    return out


def _verify(spans, line: list[Note], applied: list[Embellishment]) -> list[Embellishment]:
    """Re-derive every label from the finished line.

    A non-chord tone is a relationship, and the later passes can change a
    note's neighbours - a neighbor tone whose return note is itself decorated
    becomes something else. Rather than forbid that, the label is recomputed
    from the music that actually exists, and dropped where no device applies.
    So what the generator reports is always true of what it wrote.
    """
    order = sorted(line, key=lambda n: (n.start, n.pitch))
    index_of = {(round(n.start, 4), n.pitch): i for i, n in enumerate(order)}
    out: list[Embellishment] = []

    for item in applied:
        if item.kind in (SUSPENSION, RETARDATION):
            held = next((n for n in order if n.pitch == item.pitch
                         and n.start < item.beat < n.end + 1e-6), None)
            if held is None or _is_chord_tone(spans, item.beat, item.pitch):
                continue
            after = next((n for n in order if n.start >= held.end - 1e-6
                          and n.start > held.start), None)
            if after is None:
                continue
            kind = _classify(0, after.pitch - item.pitch)
            if kind in (SUSPENSION, RETARDATION):
                out.append(Embellishment(kind, item.beat, item.pitch))
            continue

        position = index_of.get((round(item.beat, 4), item.pitch))
        if position is None or position == 0 or position + 1 >= len(order):
            continue
        kind = _classify(item.pitch - order[position - 1].pitch,
                         order[position + 1].pitch - item.pitch)
        if kind is None:
            continue
        out.append(Embellishment(kind, item.beat, item.pitch))
    return out


def _boundary_pass(spec, spans, key, line, rng, amount, minimum, last_index, applied):
    """Suspensions, retardations and anticipations, at chord changes."""
    changes = {round(start, 4) for start, _length, _chord in spans[1:]}
    # Notes the split pass must leave alone: a suspension has to resolve to the
    # very next note, so nothing may be inserted between the two.
    frozen: set[tuple[float, int]] = set()
    if not changes:
        return line, applied, frozen

    for index in range(len(line) - 1):
        if index + 1 >= last_index:
            break
        note, following = line[index], line[index + 1]
        boundary = round(following.start, 4)
        if boundary not in changes:
            continue
        if rng.random() > amount:
            continue

        interval = following.pitch - note.pitch
        if not 0 < abs(interval) < LEAP:
            continue                      # both devices need a step

        # How much of the next note a suspension may take: up to half of it.
        next_slot = _slot(line, index + 1)
        held = min(next_slot / 2, next_slot - minimum)

        # Suspension and retardation: hold the note through the change so it
        # becomes dissonant, then resolve by step. If the held pitch belongs to
        # the new chord it is a common tone, not a suspension.
        if held >= minimum and not _is_chord_tone(spans, boundary, note.pitch):
            kind = _classify(0, interval)
            if kind in (SUSPENSION, RETARDATION):
                # Hold the preparation through the change, then resolve.
                note.duration = (following.start + held) - note.start
                following.start += held
                following.duration = max(minimum, following.duration - held)
                # Freeze both: nothing may come between a suspension and its
                # resolution, and the resolution must not become an
                # appoggiatura to something else.
                frozen.add((round(note.start, 4), note.pitch))
                frozen.add((round(following.start, 4), following.pitch))
                applied.append(Embellishment(kind, boundary, note.pitch))
                continue

        # Anticipation: arrive at the next note early, across the change.
        if not _is_chord_tone(spans, note.start, following.pitch):
            own = _slot(line, index)
            early = min(own / 2, own - minimum)
            if early >= minimum:
                begins = following.start - early
                note.duration = min(note.duration, max(minimum, begins - note.start))
                line.append(Note(begins, early * 0.9, following.pitch,
                                 max(1, note.velocity - 8)))
                frozen.add((round(begins, 4), following.pitch))
                frozen.add((round(note.start, 4), note.pitch))
                frozen.add((round(following.start, 4), following.pitch))
                applied.append(Embellishment(ANTICIPATION, begins, following.pitch))
    line.sort(key=lambda n: (n.start, n.pitch))
    line = _monophonic(line, minimum)
    return line, _verify(spans, line, applied), frozen


def _slot(line: list[Note], index: int) -> float:
    """The time a note owns: from its onset to the next onset.

    The melody shortens notes for articulation, so consecutive notes are never
    exactly contiguous. Working in slots rather than durations means a gap
    between two notes does not stop them being decorated.
    """
    note = line[index]
    if index + 1 < len(line):
        return max(note.duration, line[index + 1].start - note.start)
    return note.duration


def _split_pass(spec, spans, key, line, rng, amount, minimum, applied, frozen=()):
    """Passing tones, neighbors, appoggiaturas and escape tones."""
    out: list[Note] = []
    # Notes that must keep their own pitch on their own beat. An accented
    # device replaces the start of a note, so putting one after an unaccented
    # device would move the note that device was written to resolve to - a
    # neighbor that never comes home is an escape tone, not a neighbor.
    blocked_accented: set[float] = set()

    for index, note in enumerate(line):
        out.append(note)
        if index + 1 >= len(line):
            continue
        if (round(note.start, 4), note.pitch) in frozen:
            continue                      # a suspension resolves to the next note
        following = line[index + 1]
        slot = _slot(line, index)
        if slot < 2 * minimum:
            continue
        if rng.random() > amount:
            continue

        previous = out[-2] if len(out) > 1 else None
        candidates = _candidates(key, spans, note, following, previous)
        if round(note.start, 4) in blocked_accented:
            candidates = [c for c in candidates if not c[2]]
        if not candidates:
            continue

        # Choose the *device* first, then which form of it. Offering an upper
        # and a lower neighbor as two candidates would otherwise give neighbors
        # twice the weight of a passing tone simply for having two directions.
        by_kind: dict[str, list[tuple[str, int, bool]]] = {}
        for candidate in candidates:
            by_kind.setdefault(candidate[0], []).append(candidate)
        total = sum(WEIGHTS.get(k, 1.0) for k in by_kind)
        roll = rng.random() * total
        chosen_kind = next(iter(by_kind))
        for k in by_kind:
            roll -= WEIGHTS.get(k, 1.0)
            if roll <= 0:
                chosen_kind = k
                break
        kind, pitch, accented = rng.choice(by_kind[chosen_kind])
        half = slot / 2
        # Keep the original articulation: if the skeleton note left a gap
        # before the next, both halves leave one proportionally.
        sustain = max(0.55, min(1.0, note.duration / slot)) * half

        if accented:
            # The decoration lands on the beat and the skeleton note follows.
            out[-1] = Note(note.start, sustain, pitch, min(127, note.velocity + 4))
            out.append(Note(note.start + half, sustain, note.pitch, note.velocity))
            applied.append(Embellishment(kind, note.start, pitch))
        else:
            out[-1] = Note(note.start, sustain, note.pitch, note.velocity)
            out.append(Note(note.start + half, sustain, pitch,
                            max(1, note.velocity - 6)))
            applied.append(Embellishment(kind, note.start + half, pitch))
            # Whatever this device resolves to must still be there.
            blocked_accented.add(round(following.start, 4))
    return out, applied


def _candidates(key: _Key, spans, note: Note, following: Note,
                previous: Note | None) -> list[tuple[str, int, bool]]:
    """Every device that genuinely fits between these two notes."""
    found: list[tuple[str, int, bool]] = []

    def offer(kind: str, pitch: int, accented: bool,
              approach_from: int, departs_to: int) -> None:
        if not 21 <= pitch <= 108 or pitch == note.pitch:
            return
        beat = note.start if accented else note.start + note.duration / 2
        if _is_chord_tone(spans, beat, pitch):
            return                        # a chord tone is not a non-chord tone
        if _classify(pitch - approach_from, departs_to - pitch) != kind:
            return                        # it is not what it claims to be
        found.append((kind, pitch, accented))

    gap = following.pitch - note.pitch

    # Between two chord tones a third apart: the note in between, passing.
    if 0 < abs(gap) <= 4:
        middle = key.pitch((key.degree(note.pitch) + key.degree(following.pitch)) // 2) \
            if abs(key.degree(following.pitch) - key.degree(note.pitch)) == 2 else None
        if middle is not None:
            offer(PASSING, middle, False, note.pitch, following.pitch)

    # Between two notes at the same pitch: step away and come back.
    if gap == 0:
        for direction in (1, -1):
            offer(NEIGHBOR, key.step(note.pitch, direction), False,
                  note.pitch, following.pitch)

    # Approached by leap, left by step: an accented appoggiatura.
    if previous is not None:
        for direction in (1, -1):
            offer(APPOGGIATURA, key.step(note.pitch, direction), True,
                  previous.pitch, note.pitch)

    # Step away, then leap the other way into the next note.
    if abs(gap) >= LEAP:
        direction = -1 if gap > 0 else 1
        offer(ESCAPE, key.step(note.pitch, direction), False,
              note.pitch, following.pitch)

    return found
