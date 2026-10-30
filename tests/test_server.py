"""The DAW's server: Compose, MIDI in and out, and storage, over real HTTP."""

import json
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer
from pathlib import Path

from server import app as server


class TestServer(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.old_root = server.USER_ROOT
        server.USER_ROOT = Path(cls.tmp.name) / "user"
        quiet = type("Quiet", (server.Handler,), {"log_message": lambda *a: None})
        cls.httpd = ThreadingHTTPServer(("127.0.0.1", 0), quiet)
        cls.base = f"http://127.0.0.1:{cls.httpd.server_address[1]}"
        threading.Thread(target=cls.httpd.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.httpd.shutdown()
        cls.httpd.server_close()
        server.USER_ROOT = cls.old_root
        cls.tmp.cleanup()

    def call(self, method, path, body=None, json_body=None):
        data = json.dumps(json_body).encode() if json_body is not None else body
        req = urllib.request.Request(self.base + path, data=data, method=method)
        try:
            with urllib.request.urlopen(req) as r:
                return r.status, r.read(), r.headers.get("Content-Type", "")
        except urllib.error.HTTPError as e:
            return e.code, e.read(), e.headers.get("Content-Type", "")

    def test_compose_returns_five_parts(self):
        status, body, _ = self.call("POST", "/api/compose", json_body={"prompt": "a calm waltz in D minor", "seed": 4})
        self.assertEqual(status, 200)
        d = json.loads(body)
        self.assertEqual([t["role"] for t in d["song"]["tracks"]],
                         ["melody", "countermelody", "harmony", "bass", "drums"])
        self.assertEqual(d["spec"]["seed"], 4)
        self.assertEqual(d["song"]["meter"], [3, 4])

    def test_midi_round_trip_keeps_notes_controls_and_key(self):
        notes = [{"start": i * 0.5, "duration": 0.5, "pitch": p, "velocity": 90}
                 for i, p in enumerate([62, 64, 65, 67, 69, 70, 72, 74, 62, 57, 62])]
        song = {"tempo": 96, "meter": [3, 4], "key": "D Minor (Natural)",
                "tracks": [{"name": "Tune", "notes": notes, "controls": [{"beat": 0, "controller": 11, "value": 70}]},
                           {"name": "Kit", "drums": True, "notes": [{"start": 0, "duration": 0.25, "pitch": 36}]}]}
        status, midi, ctype = self.call("POST", "/api/midi/write", json_body=song)
        self.assertEqual(status, 200)
        self.assertEqual(ctype, "audio/midi")
        self.assertEqual(midi[:4], b"MThd")
        status, body, _ = self.call("POST", "/api/midi/read", body=midi)
        d = json.loads(body)
        self.assertEqual(d["meter"], [3, 4])
        self.assertAlmostEqual(d["tempo"], 96, places=1)
        tune, kit = d["tracks"]
        self.assertEqual([n["pitch"] for n in tune["notes"]], [n["pitch"] for n in notes])
        self.assertEqual(tune["controls"], [{"start": 0, "controller": 11, "value": 70}])
        self.assertTrue(kit["drums"])
        self.assertEqual(d["key"]["tonic"], 2)

    def test_bad_midi_is_refused_not_fatal(self):
        status, body, _ = self.call("POST", "/api/midi/read", body=b"hello")
        self.assertEqual(status, 400)
        self.assertIn("error", json.loads(body))

    def test_store_put_then_get(self):
        self.assertEqual(self.call("GET", "/api/store/battlepass")[0], 204)
        self.assertEqual(self.call("PUT", "/api/store/battlepass", json_body={"xp": 120})[0], 200)
        status, body, _ = self.call("GET", "/api/store/battlepass")
        self.assertEqual((status, json.loads(body)), (200, {"xp": 120}))

    def test_store_refuses_paths_and_non_json(self):
        self.assertEqual(self.call("PUT", "/api/store/..%2Fescape", json_body={})[0], 400)
        self.assertEqual(self.call("PUT", "/api/store/ok", body=b"not json")[0], 400)

    def test_serves_devices_with_spaces_in_their_names(self):
        status, body, ctype = self.call("GET", "/devices/Midi%20Evolver.jsfx")
        self.assertEqual(status, 200)
        self.assertTrue(ctype.startswith("text/plain"))
        self.assertIn(b"slider1", body)

    def test_does_not_serve_outside_web(self):
        self.assertEqual(self.call("GET", "/../server/app.py")[0], 404)
        self.assertEqual(self.call("GET", "/%2e%2e/server/app.py")[0], 404)


if __name__ == "__main__":
    unittest.main()
