"""Middaw's local web server.

Standard library only: no framework, no build step, no install. Run it and
open the printed URL.
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

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from middaw.corpus.stats import CorpusPriors, load_corpus_priors   # noqa: E402
from middaw.prompt import parse_prompt                              # noqa: E402
from middaw.render import render                                    # noqa: E402
from middaw.vocab import load_vocabulary                            # noqa: E402

WEB_ROOT = ROOT / "web"
MAX_BODY = 64 * 1024
_SAFE_NAME = re.compile(r"[^A-Za-z0-9]+")


def slugify(text: str, fallback: str = "middaw") -> str:
    slug = _SAFE_NAME.sub("-", text.strip().lower()).strip("-")
    return (slug[:48] or fallback)


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
        target = (WEB_ROOT / path.lstrip("/")).resolve()
        if WEB_ROOT.resolve() in target.parents and target.is_file():
            return self._send_file(target)
        return self._send_error(404, "not found")

    def do_POST(self):  # noqa: N802
        if self.path.split("?", 1)[0] != "/api/generate":
            return self._send_error(404, "not found")
        try:
            length = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            return self._send_error(400, "bad content length")
        if length > MAX_BODY:
            return self._send_error(413, "prompt too large")
        try:
            payload = json.loads(self.rfile.read(length) or b"{}")
        except json.JSONDecodeError:
            return self._send_error(400, "body must be JSON")

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

        body = result.to_dict()
        body["midiBase64"] = base64.b64encode(result.midi).decode("ascii")
        body["filename"] = f"{slugify(prompt or 'middaw')}-{spec.seed}.mid"
        body["summary"] = spec.summary()
        return self._send_json(body)

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
        data = path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
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
