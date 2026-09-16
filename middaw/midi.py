"""A small, dependency-free Standard MIDI File reader and writer.

Only the subset Middaw needs: format 0/1 files, note on/off, program change,
tempo, time signature, key signature and track names. Written by hand so the
project has no runtime dependencies and so the byte layout stays inspectable
(MIDI accuracy is the entire premise of the product).
"""

from __future__ import annotations

import struct
from dataclasses import dataclass

from middaw.song import DRUM_CHANNEL, Note, Song, Track

MICROSECONDS_PER_MINUTE = 60_000_000


# ---------------------------------------------------------------- writing ---
def _vlq(value: int) -> bytes:
    """Variable-length quantity, as used for MIDI delta times."""
    if value < 0:
        raise ValueError("delta time cannot be negative")
    buffer = [value & 0x7F]
    value >>= 7
    while value:
        buffer.append((value & 0x7F) | 0x80)
        value >>= 7
    return bytes(reversed(buffer))


def _chunk(tag: bytes, payload: bytes) -> bytes:
    return tag + struct.pack(">I", len(payload)) + payload


def _key_signature_bytes(key_name: str) -> bytes:
    """Best-effort key signature meta event (sharps/flats count + major/minor)."""
    sharps_major = {"C": 0, "G": 1, "D": 2, "A": 3, "E": 4, "B": 5, "F#": 6, "F": -1,
                    "A#": -2, "D#": -3, "G#": -4, "C#": -5}
    parts = key_name.split()
    root = parts[0] if parts else "C"
    minorish = len(parts) > 1 and parts[1].startswith(("min", "aeol", "dor", "phry", "loc", "harm", "mel", "blu"))
    accidentals = sharps_major.get(root, 0)
    if minorish:
        accidentals = max(-7, min(7, accidentals - 3))
    return struct.pack(">bB", accidentals, 1 if minorish else 0)


def song_to_bytes(song: Song) -> bytes:
    """Serialise a `Song` to a format-1 Standard MIDI File."""
    tpb = song.ticks_per_beat

    conductor: list[tuple[int, int, bytes]] = []
    tempo_us = int(round(MICROSECONDS_PER_MINUTE / max(1, song.tempo)))
    conductor.append((0, 0, b"\xff\x51\x03" + struct.pack(">I", tempo_us)[1:]))
    num, den = song.meter
    denom_power = max(0, den.bit_length() - 1)
    conductor.append((0, 0, b"\xff\x58\x04" + bytes([num, denom_power, 24, 8])))
    conductor.append((0, 0, b"\xff\x59\x02" + _key_signature_bytes(song.key_name)))
    conductor.append((0, 1, b"\xff\x03" + _vlq(len(b"Middaw")) + b"Middaw"))

    chunks = [_chunk(b"MTrk", _events_to_track(conductor))]

    for track in song.tracks:
        events: list[tuple[int, int, bytes]] = []
        name = track.name.encode("utf-8")[:64]
        events.append((0, 0, b"\xff\x03" + _vlq(len(name)) + name))
        events.append((0, 1, bytes([0xC0 | (track.channel & 0x0F), track.program & 0x7F])))
        for note in track.notes:
            start = int(round(note.start * tpb))
            end = max(start + 1, int(round(note.end * tpb)))
            pitch = max(0, min(127, int(note.pitch)))
            velocity = max(1, min(127, int(note.velocity)))
            # Note-offs sort before note-ons at the same tick so repeated
            # pitches retrigger cleanly instead of cancelling each other.
            events.append((end, 2, bytes([0x80 | (track.channel & 0x0F), pitch, 64])))
            events.append((start, 3, bytes([0x90 | (track.channel & 0x0F), pitch, velocity])))
        chunks.append(_chunk(b"MTrk", _events_to_track(events)))

    header = struct.pack(">HHH", 1, len(chunks), tpb)
    return _chunk(b"MThd", header) + b"".join(chunks)


def _events_to_track(events: list[tuple[int, int, bytes]]) -> bytes:
    events = sorted(events, key=lambda e: (e[0], e[1]))
    out = bytearray()
    previous = 0
    for tick, _order, payload in events:
        out += _vlq(tick - previous)
        out += payload
        previous = tick
    out += _vlq(0) + b"\xff\x2f\x00"
    return bytes(out)


# ---------------------------------------------------------------- reading ---
@dataclass
class MidiFile:
    ticks_per_beat: int
    tempo: float
    meter: tuple[int, int]
    tracks: list[Track]

    @property
    def notes(self) -> list[Note]:
        return sorted((n for t in self.tracks for n in t.notes), key=lambda n: (n.start, n.pitch))

    @property
    def pitched_notes(self) -> list[Note]:
        """Everything except channel 10, where a note number is an instrument."""
        return sorted((n for t in self.tracks if t.channel != DRUM_CHANNEL
                       for n in t.notes), key=lambda n: (n.start, n.pitch))


class MidiParseError(ValueError):
    pass


def _read_vlq(data: bytes, pos: int) -> tuple[int, int]:
    value = 0
    for _ in range(4):
        if pos >= len(data):
            raise MidiParseError("truncated variable-length quantity")
        byte = data[pos]
        pos += 1
        value = (value << 7) | (byte & 0x7F)
        if not byte & 0x80:
            return value, pos
    raise MidiParseError("variable-length quantity too long")


def bytes_to_song(data: bytes) -> MidiFile:
    """Parse a Standard MIDI File into absolute-time note lists."""
    if data[:4] != b"MThd":
        raise MidiParseError("not a Standard MIDI File (missing MThd)")
    (header_len,) = struct.unpack(">I", data[4:8])
    fmt, ntrks, division = struct.unpack(">HHH", data[8:14])
    if division & 0x8000:
        raise MidiParseError("SMPTE time division is not supported")
    ticks_per_beat = division or 480
    pos = 8 + header_len

    tempo = 120.0
    meter = (4, 4)
    tracks: list[Track] = []

    for _ in range(ntrks):
        if pos + 8 > len(data):
            break
        tag = data[pos:pos + 4]
        (length,) = struct.unpack(">I", data[pos + 4:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        pos += 8 + length
        if tag != b"MTrk":
            continue

        track = Track(name="", channel=0)
        open_notes: dict[tuple[int, int], list[tuple[int, int]]] = {}
        tick = 0
        cursor = 0
        running_status = 0
        while cursor < len(body):
            delta, cursor = _read_vlq(body, cursor)
            tick += delta
            if cursor >= len(body):
                break
            status = body[cursor]
            if status & 0x80:
                cursor += 1
                running_status = status if status < 0xF0 else 0
            else:
                status = running_status
                if not status:
                    raise MidiParseError("running status with no prior status byte")

            if status == 0xFF:
                meta_type = body[cursor]
                cursor += 1
                length_, cursor = _read_vlq(body, cursor)
                payload = body[cursor:cursor + length_]
                cursor += length_
                if meta_type == 0x51 and length_ == 3:
                    us = (payload[0] << 16) | (payload[1] << 8) | payload[2]
                    if us:
                        tempo = MICROSECONDS_PER_MINUTE / us
                elif meta_type == 0x58 and length_ >= 2:
                    meter = (payload[0], 2 ** payload[1])
                elif meta_type == 0x03 and not track.name:
                    track.name = payload.decode("utf-8", "replace")
            elif status in (0xF0, 0xF7):
                length_, cursor = _read_vlq(body, cursor)
                cursor += length_
            else:
                kind = status & 0xF0
                channel = status & 0x0F
                if kind in (0x80, 0x90, 0xA0, 0xB0, 0xE0):
                    data1, data2 = body[cursor], body[cursor + 1]
                    cursor += 2
                    if kind == 0x90 and data2 > 0:
                        open_notes.setdefault((channel, data1), []).append((tick, data2))
                    elif kind == 0x80 or (kind == 0x90 and data2 == 0):
                        stack = open_notes.get((channel, data1))
                        if stack:
                            start_tick, velocity = stack.pop(0)
                            track.channel = channel
                            track.notes.append(Note(
                                start=start_tick / ticks_per_beat,
                                duration=max(1, tick - start_tick) / ticks_per_beat,
                                pitch=data1,
                                velocity=velocity,
                            ))
                elif kind in (0xC0, 0xD0):
                    if kind == 0xC0:
                        track.program = body[cursor]
                    cursor += 1
                else:
                    cursor += 1
        track.notes.sort(key=lambda n: (n.start, n.pitch))
        tracks.append(track)

    return MidiFile(ticks_per_beat=ticks_per_beat, tempo=tempo, meter=meter, tracks=tracks)


def read_midi(path) -> MidiFile:
    with open(path, "rb") as fh:
        return bytes_to_song(fh.read())
