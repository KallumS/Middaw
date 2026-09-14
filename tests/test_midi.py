import unittest

from middaw.midi import MidiParseError, _vlq, bytes_to_song, song_to_bytes
from middaw.song import Note, Song, Track


def _demo_song() -> Song:
    return Song(
        tempo=96,
        meter=(3, 4),
        ticks_per_beat=480,
        key_name="D minor",
        tracks=[
            Track(name="Chords", program=0, channel=0, notes=[
                Note(0.0, 1.0, 62, 80), Note(0.0, 1.0, 65, 72), Note(1.0, 2.0, 69, 64),
            ]),
            Track(name="Melody", program=0, channel=1, notes=[
                Note(0.5, 0.5, 74, 90), Note(1.0, 0.25, 72, 88), Note(2.0, 1.0, 74, 84),
            ]),
        ],
    )


class TestVariableLengthQuantity(unittest.TestCase):
    def test_known_values(self):
        self.assertEqual(_vlq(0), b"\x00")
        self.assertEqual(_vlq(127), b"\x7f")
        self.assertEqual(_vlq(128), b"\x81\x00")
        self.assertEqual(_vlq(0x3FFF), b"\xff\x7f")
        self.assertEqual(_vlq(0x100000), b"\xc0\x80\x00")

    def test_negative_rejected(self):
        with self.assertRaises(ValueError):
            _vlq(-1)


class TestRoundTrip(unittest.TestCase):
    def test_header_is_well_formed(self):
        data = song_to_bytes(_demo_song())
        self.assertEqual(data[:4], b"MThd")
        self.assertEqual(data[4:8], b"\x00\x00\x00\x06")
        self.assertEqual(data.count(b"MTrk"), 3)   # conductor + two parts

    def test_notes_survive_a_round_trip(self):
        song = _demo_song()
        parsed = bytes_to_song(song_to_bytes(song))
        self.assertEqual(parsed.ticks_per_beat, 480)
        self.assertEqual(parsed.meter, (3, 4))
        self.assertAlmostEqual(parsed.tempo, 96, delta=0.2)

        original = sorted((n.pitch, round(n.start, 4), round(n.duration, 4))
                          for n in song.notes)
        recovered = sorted((n.pitch, round(n.start, 4), round(n.duration, 4))
                           for n in parsed.notes)
        self.assertEqual(original, recovered)

    def test_velocities_survive(self):
        parsed = bytes_to_song(song_to_bytes(_demo_song()))
        self.assertEqual(sorted(n.velocity for n in parsed.notes),
                         sorted(n.velocity for n in _demo_song().notes))

    def test_track_names_and_channels_survive(self):
        parsed = bytes_to_song(song_to_bytes(_demo_song()))
        names = [t.name for t in parsed.tracks if t.notes]
        self.assertEqual(names, ["Chords", "Melody"])
        self.assertEqual([t.channel for t in parsed.tracks if t.notes], [0, 1])

    def test_repeated_pitch_retriggers(self):
        song = Song(tracks=[Track(name="x", notes=[
            Note(0.0, 1.0, 60, 80), Note(1.0, 1.0, 60, 80),
        ])])
        parsed = bytes_to_song(song_to_bytes(song))
        self.assertEqual(len(parsed.notes), 2)
        self.assertAlmostEqual(parsed.notes[1].start, 1.0, places=4)

    def test_rejects_non_midi(self):
        with self.assertRaises(MidiParseError):
            bytes_to_song(b"this is not a midi file at all")


if __name__ == "__main__":
    unittest.main()
