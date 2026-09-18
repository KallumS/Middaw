"""The part contract: four voices and a kit.

Every generation is laid out as the same five MIDI tracks, in the same order,
on the same channels: melody, countermelody, harmony, bass — and drums. The
first four are the standard Western texture — a tune, a line answering it, the
harmony under them and a bass — and keeping it fixed means a player can assign
one instrument per part once and have every result land on the same slots.

**Drums are not a fifth voice.** They have no key, no register and no chord to
belong to, they live on MIDI channel 10 where a note number names an instrument
rather than a pitch, and plenty of styles do not have them at all. They are a
different kind of thing that happens to arrive in the same file, which is why
they sit outside `VOICE_PARTS` and why a hymn's drum track is empty rather than
apologetic.

The harmony part is one job done one of three ways: comped chords, a repeating
figure, or a broken chord. A style picks the treatment; it never gets an extra
track for it.
"""

from __future__ import annotations

#: In track order. The pitched parts take channels 0-3; drums take channel 10,
#: as every piece of music software expects.
PARTS = ("melody", "countermelody", "harmony", "bass", "drums")

#: The four that carry pitch. A key, a register and a chord apply to these.
PITCHED_PARTS = PARTS[:4]

PART_NAMES = {
    "melody": "Melody",
    "countermelody": "Countermelody",
    "harmony": "Harmony",
    "bass": "Bass",
    "drums": "Drums",
}

#: MIDI channel per part, counting from zero.
PART_CHANNELS = {"melody": 0, "countermelody": 1, "harmony": 2, "bass": 3,
                 "drums": 9}

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
