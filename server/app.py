"""Middaw's local web server.

Standard library only: no framework, no build step, no install. Run it and
open the printed URL.

The DAW itself runs in the browser. The server does the three things that are
Python's: Compose (prompt -> spec -> five parts), reading and writing Standard
MIDI Files with Middaw's own codec, and keeping what the DAW stores (the
Battle Pass, preferences) in `data/user/` so it survives a cleared browser.
"""

from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import re
import sys
import traceback
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from middaw.corpus.analyse import detect_key                         # noqa: E402
from middaw.corpus.stats import CorpusPriors, load_corpus_priors   # noqa: E402
from middaw.midi import MidiParseError, bytes_to_song, song_to_bytes  # noqa: E402
from middaw.scaleview import key_for                                # noqa: E402
from middaw.song import DRUM_CHANNEL, Control, Note, Song, Track    # noqa: E402
from middaw.prompt import parse_prompt                              # noqa: E402
from middaw.render import render                                    # noqa: E402
from middaw.vocab import load_vocabulary                            # noqa: E402

WEB_ROOT = ROOT / "web"
USER_ROOT = ROOT / "data" / "user"
MAX_BODY = 64 * 1024
MAX_FILE = 8 * 1024 * 1024
_SAFE_NAME = re.compile(r"[^A-Za-z0-9]+")
_STORE_KEY = re.compile(r"^[a-z0-9][a-z0-9_-]{0,63}$")
mimetypes.add_type("text/plain", ".jsfx")
mimetypes.add_type("text/plain", ".jsfx-inc")
mimetypes.add_type("text/plain", ".lua")
mimetypes.add_type("text/javascript", ".js")


def slugify(text: str, fallback: str = "middaw") -> str:
    slug = _SAFE_NAME.sub("-", text.strip().lower()).strip("-")
    return (slug[:48] or fallback)


def song_from_payload(payload: dict) -> Song:
    """{tempo, meter, key, tracks[{name, drums, notes, controls}]} -> Song."""
    meter = payload.get("meter") or [4, 4]
    song = Song(tempo=int(round(float(payload.get("tempo") or 120))),
                meter=(int(meter[0]), int(meter[1])),
                key_name=str(payload.get("key") or "C Major"))
    channel = 0
    for item in payload.get("tracks") or []:
        drums = bool(item.get("drums"))
        if drums:
            chan = DRUM_CHANNEL
        else:
            chan = channel
            channel += 1
            if channel == DRUM_CHANNEL:
                channel += 1
            chan = min(chan, 15)
        song.tracks.append(Track(
            name=str(item.get("name") or "Track")[:64], channel=chan,
            notes=[Note(start=max(0.0, float(n["start"])),
                        duration=max(1 / 480, float(n["duration"])),
                        pitch=int(n["pitch"]), velocity=int(n.get("velocity", 90)))
                   for n in item.get("notes") or []],
            controls=[Control(start=max(0.0, float(c["beat"])), controller=int(c["controller"]),
                              value=int(c["value"]))
                      for c in item.get("controls") or []]))
    return song


def payload_from_midi(midi) -> dict:
    """A read file as the DAW takes it, with the key Middaw hears in it."""
    pitched = midi.pitched_notes
    key = None
    if len(pitched) >= 8:
        tonic, mode, _confidence = detect_key(pitched)
        key = {"label": key_for(tonic, mode).label, "tonic": tonic, "mode": mode}
    return {
        "tempo": round(midi.tempo, 3),
        "meter": [midi.meter[0], midi.meter[1]],
        "key": key,
        "tracks": [{"name": t.name, "drums": t.channel == DRUM_CHANNEL, "program": t.program,
                    "notes": [n.to_dict() for n in t.notes],
                    "controls": [c.to_dict() for c in t.controls]}
                   for t in midi.tracks if t.notes or t.controls],
    }


class Handler(BaseHTTPRequestHandler):
    server_version = "Middaw"
    priors: CorpusPriors | None = None

    # ------------------------------------------------------------- routing --
    def do_GET(self):  # noqa: N802
        path = self.path.split("?", 1)[0]
        if path == "/":
            return self._send_file(WEB_ROOT / "index.html")
        if path == "/api/vocabulary":
            vocab = load_vocabulary()
            return self._send_json({
                "tags": vocab.all_tags(),
                "genres": {k: v.get("label", k) for k, v in vocab.genres.items()},
                "moods": {k: v.get("label", k) for k, v in vocab.moods.items()},
                "corpus": (self.priors.describe() if self.priors else
                           {"entries": 0, "note": "no corpus loaded"}),
            })
        if path.startswith("/api/store/"):
            return self._store_get(path[len("/api/store/"):])
        target = (WEB_ROOT / unquote(path).lstrip("/")).resolve()
        if WEB_ROOT.resolve() in target.parents and target.is_file():
            return self._send_file(target)
        return self._send_error(404, "not found")

    def do_POST(self):  # noqa: N802
        path = self.path.split("?", 1)[0]
        routes = {"/api/compose": self._compose, "/api/generate": self._compose,
                  "/api/midi/write": self._midi_write, "/api/midi/read": self._midi_read}
        if path not in routes:
            return self._send_error(404, "not found")
        body = self._read_body(MAX_FILE if path == "/api/midi/read" else MAX_BODY * 16)
        if body is None:
            return
        return routes[path](body)

    def do_PUT(self):  # noqa: N802
        path = self.path.split("?", 1)[0]
        if not path.startswith("/api/store/"):
            return self._send_error(404, "not found")
        body = self._read_body(MAX_FILE)
        if body is None:
            return
        return self._store_put(path[len("/api/store/"):], body)

    def _read_body(self, limit: int):
        try:
            length = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            self._send_error(400, "bad content length")
            return None
        if length > limit:
            self._send_error(413, "too large")
            return None
        return self.rfile.read(length)

    @staticmethod
    def _json(body: bytes):
        try:
            payload = json.loads(body or b"{}")
        except json.JSONDecodeError:
            return None
        return payload if isinstance(payload, dict) else None

    # ------------------------------------------------------------- compose --
    def _compose(self, body: bytes):
        payload = self._json(body)
        if payload is None:
            return self._send_error(400, "body must be a JSON object")
        prompt = str(payload.get("prompt") or "").strip()
        if len(prompt) > 2000:
            return self._send_error(400, "prompt too long")

        seed = payload.get("seed")
        overrides = {key: payload.get(key) for key in ("bars", "tempo", "density")
                     if payload.get(key) is not None}
        try:
            seed = int(seed) if seed is not None else None
            spec = parse_prompt(prompt, seed=seed, overrides=overrides or None)
            result = render(spec, priors=self.priors)
        except Exception:                      # a bad prompt must not kill the server
            traceback.print_exc()
            return self._send_error(500, "generation failed")

        out = result.to_dict()
        out["midiBase64"] = base64.b64encode(result.midi).decode("ascii")
        out["filename"] = f"{slugify(prompt or 'middaw')}-{spec.seed}.mid"
        out["summary"] = spec.summary()
        return self._send_json(out)

    # ---------------------------------------------------------------- midi --
    def _midi_write(self, body: bytes):
        """The DAW's tracks as a Standard MIDI File, by Middaw's own writer."""
        payload = self._json(body)
        if payload is None:
            return self._send_error(400, "body must be a JSON object")
        try:
            song = song_from_payload(payload)
        except (TypeError, ValueError, KeyError) as exc:
            return self._send_error(400, f"bad song: {exc}")
        data = song_to_bytes(song)
        self.send_response(200)
        self.send_header("Content-Type", "audio/midi")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _midi_read(self, body: bytes):
        try:
            midi = bytes_to_song(body)
        except (MidiParseError, IndexError, ValueError) as exc:
            return self._send_error(400, str(exc) or "not a MIDI file")
        return self._send_json(payload_from_midi(midi))

    # --------------------------------------------------------------- store --
    def _store_path(self, key: str):
        return USER_ROOT / f"{key}.json" if _STORE_KEY.match(key) else None

    def _store_get(self, key: str):
        target = self._store_path(key)
        if target is None:
            return self._send_error(400, "bad key")
        if not target.is_file():
            self.send_response(204)          # nothing stored yet: not an error
            self.end_headers()
            return None
        return self._send_bytes(target.read_bytes(), "application/json")

    def _store_put(self, key: str, body: bytes):
        target = self._store_path(key)
        if target is None:
            return self._send_error(400, "bad key")
        try:
            json.loads(body)
        except json.JSONDecodeError:
            return self._send_error(400, "body must be JSON")
        USER_ROOT.mkdir(parents=True, exist_ok=True)
        temp = target.with_suffix(".tmp")
        temp.write_bytes(body)
        temp.replace(target)                  # never leave half a file behind
        return self._send_json({"ok": True})

    # ------------------------------------------------------------- helpers --
    def _send_json(self, payload: dict, status: int = 200):
        data = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def _send_error(self, status: int, message: str):
        self._send_json({"error": message}, status=status)

    def _send_file(self, path: Path):
        if not path.is_file():
            return self._send_error(404, "not found")
        content_type = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        if content_type.startswith("text/"):
            content_type += "; charset=utf-8"
        return self._send_bytes(path.read_bytes(), content_type)

    def _send_bytes(self, data: bytes, content_type: str):
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, fmt, *args):
        sys.stderr.write(f"  {self.address_string()} {fmt % args}\n")


def main(argv=None):
    parser = argparse.ArgumentParser(description="Run the Middaw web app")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--corpus", default=str(ROOT / "data" / "corpus"),
                        help="directory holding manifest.json")
    args = parser.parse_args(argv)

    Handler.priors = load_corpus_priors(Path(args.corpus))
    described = Handler.priors.describe() if Handler.priors else {"entries": 0}
    print(f"Middaw on http://{args.host}:{args.port}")
    print(f"  corpus: {described['entries']} labelled entries")
    ThreadingHTTPServer((args.host, args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
