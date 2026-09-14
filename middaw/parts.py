"""The four-part contract.

Every generation is laid out as the same four MIDI tracks, in the same order,
on the same channels: melody, countermelody, harmony, bass. That is the
standard Western texture — a tune, a line answering it, the harmony under them
and a bass — and keeping it fixed means a player can assign one instrument per
part once and have every result land on the same four slots.

The harmony part is one job done one of three ways: comped chords, a repeating
figure, or a broken chord. A style picks the treatment; it never gets an extra
track for it.
"""

from __future__ import annotations

#: In track order. The index is also the MIDI channel.
PARTS = ("melody", "countermelody", "harmony", "bass")

PART_NAMES = {
    "melody": "Melody",
    "countermelody": "Countermelody",
    "harmony": "Harmony",
    "bass": "Bass",
}

#: How the harmony part can be realised.
TREATMENTS = ("chords", "ostinato", "arpeggio")

#: Every voice word the vocabulary knows, and the part it belongs to.
VOICE_PARTS = {
    "melody": "melody",
    "countermelody": "countermelody",
    "chords": "harmony",
    "ostinato": "harmony",
    "arpeggio": "harmony",
    "bass": "bass",
}

ALL_VOICES = tuple(VOICE_PARTS)
