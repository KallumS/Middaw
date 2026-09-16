"""Timeline containers shared by the generator and the MIDI codec."""

from __future__ import annotations

from dataclasses import dataclass, field

#: MIDI channel 10, counted from zero, where note numbers name instruments.
DRUM_CHANNEL = 9


@dataclass
class Note:
    start: float        # beats (quarter notes) from the start of the song
    duration: float     # beats
    pitch: int          # MIDI note number
    velocity: int = 80

    @property
    def end(self) -> float:
        return self.start + self.duration

    def to_dict(self) -> dict:
        return {
            "start": round(self.start, 5),
            "duration": round(self.duration, 5),
            "pitch": self.pitch,
            "velocity": self.velocity,
        }


@dataclass
class Track:
    name: str
    program: int = 0          # GM program; 0 = acoustic grand piano
    channel: int = 0
    role: str = ""            # which part this is: a voice, or the kit
    detail: str = ""          # how the part is realised, where that varies
    notes: list[Note] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "name": self.name,
            "program": self.program,
            "channel": self.channel,
            "role": self.role,
            "detail": self.detail,
            "notes": [n.to_dict() for n in self.notes],
        }


@dataclass
class Song:
    tempo: int = 100
    meter: tuple[int, int] = (4, 4)
    ticks_per_beat: int = 480
    key_name: str = "C major"
    tracks: list[Track] = field(default_factory=list)

    @property
    def notes(self) -> list[Note]:
        return [n for t in self.tracks for n in t.notes]

    @property
    def pitched_notes(self) -> list[Note]:
        """Everything except the kit.

        On channel 10 a note number is an instrument, not a pitch: note 36 is a
        kick drum, and handing it to a key detector produces a piece in C.
        """
        return [n for t in self.tracks if t.channel != DRUM_CHANNEL
                for n in t.notes]

    @property
    def length_beats(self) -> float:
        return max((n.end for n in self.notes), default=0.0)

    def to_dict(self) -> dict:
        return {
            "tempo": self.tempo,
            "meter": [self.meter[0], self.meter[1]],
            "ticksPerBeat": self.ticks_per_beat,
            "key": self.key_name,
            "lengthBeats": round(self.length_beats, 4),
            "tracks": [t.to_dict() for t in self.tracks],
        }
