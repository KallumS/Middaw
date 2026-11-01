import unittest

from middaw.midi import MidiParseError, _vlq, bytes_to_song, song_to_bytes
from middaw.song import Control, Note, Song, Track


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


class TestKeySignature(unittest.TestCase):
    """The key signature meta event names the key the music is in.

    Before this, every flat key read as C (`Bb Major` was not in the lookup)
    and every mode as its own major key (D dorian with two sharps)."""

    def sig(self, tonic, mode):
        from middaw.midi import _key_signature_bytes
        from middaw.scaleview import key_for
        sf, mi = _key_signature_bytes(key_for(tonic, mode).label)
        return (sf - 256 if sf > 127 else sf), mi

    def test_flat_keys(self):
        self.assertEqual(self.sig(10, "major"), (-2, 0))     # Bb
        self.assertEqual(self.sig(3, "major"), (-3, 0))      # Eb
        self.assertEqual(self.sig(5, "minor"), (-4, 1))      # F minor

    def test_sharp_keys(self):
        self.assertEqual(self.sig(9, "major"), (3, 0))       # A
        self.assertEqual(self.sig(4, "minor"), (1, 1))       # E minor
        self.assertEqual(self.sig(6, "major"), (6, 0))       # F#

    def test_modes_take_their_parent_signature(self):
        self.assertEqual(self.sig(2, "dorian"), (0, 1))
        self.assertEqual(self.sig(4, "phrygian"), (0, 1))
        self.assertEqual(self.sig(5, "lydian"), (0, 0))
        self.assertEqual(self.sig(7, "mixolydian"), (0, 0))

    def test_altered_minors_use_the_natural_minor_signature(self):
        self.assertEqual(self.sig(9, "harmonic_minor"), (0, 1))
        self.assertEqual(self.sig(0, "melodic_minor"), (-3, 1))

    def test_plain_names_still_read(self):
        from middaw.midi import _key_signature_bytes
        self.assertEqual(list(_key_signature_bytes("D minor")), [255, 1])


class TestControllers(unittest.TestCase):
    """AutoCC's curves and a recorded sustain pedal leave in the file."""

    def test_controls_round_trip_in_order(self):
        track = Track(name="Strings", channel=2, notes=[Note(0, 2, 60, 90)],
                      controls=[Control(0, 11, 40), Control(1, 11, 100), Control(1.5, 64, 127)])
        back = bytes_to_song(song_to_bytes(Song(tracks=[track]))).tracks[1]
        self.assertEqual([(c.start, c.controller, c.value) for c in back.controls],
                         [(0, 11, 40), (1, 11, 100), (1.5, 64, 127)])
        self.assertEqual(back.notes[0].pitch, 60)

    def test_controller_precedes_note_at_same_tick(self):
        track = Track(name="x", notes=[Note(0, 1, 60, 90)], controls=[Control(0, 11, 30)])
        data = song_to_bytes(Song(tracks=[track]))
        self.assertLess(data.index(bytes([0xB0, 11, 30])), data.index(bytes([0x90, 60, 90])))


if __name__ == "__main__":
    unittest.main()
