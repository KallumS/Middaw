#!/usr/bin/env python3
"""Vendor a General MIDI acoustic grand piano soundfont into web/soundfonts/.

The app falls back to a CDN and then to a built-in synth tone, so this is an
optimisation and an offline convenience, not a requirement.

The soundfont is Benjamin Gleitzman's MIDI.js build of FluidR3_GM, which is
MIT-licensed; FluidR3_GM itself is distributed under the MIT licence by Frank
Wen. The downloaded file is not committed - see .gitignore.
"""

from __future__ import annotations

import argparse
import sys
import urllib.request
from pathlib import Path

DEFAULT_URL = ("https://gleitz.github.io/midi-js-soundfonts/FluidR3_GM/"
               "acoustic_grand_piano-mp3.js")
TARGET = Path(__file__).resolve().parent.parent / "web" / "soundfonts"


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default=DEFAULT_URL)
    parser.add_argument("--out", default=str(TARGET))
    args = parser.parse_args(argv)

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    destination = out_dir / args.url.rsplit("/", 1)[-1]

    print(f"fetching {args.url}")
    try:
        with urllib.request.urlopen(args.url, timeout=120) as response:
            data = response.read()
    except Exception as error:
        print(f"could not fetch the soundfont: {error}", file=sys.stderr)
        print("the app will fall back to the CDN, then to its built-in tone",
              file=sys.stderr)
        return 1

    destination.write_bytes(data)
    print(f"wrote {destination} ({len(data) / 1_000_000:.1f} MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
