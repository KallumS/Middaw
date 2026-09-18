"""Command line entry point: `python -m middaw "a sad lo-fi loop" -o out.mid`."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from middaw.corpus.stats import load_corpus_priors
from middaw.prompt import parse_prompt
from middaw.render import render

ROOT = Path(__file__).resolve().parent.parent


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="middaw", description="Text to MIDI")
    parser.add_argument("prompt", nargs="*", help="what you want to create")
    parser.add_argument("-o", "--output", default=None, help="path for the .mid file")
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--bars", type=int, default=None)
    parser.add_argument("--tempo", type=int, default=None)
    parser.add_argument("--corpus", default=str(ROOT / "data" / "corpus"))
    parser.add_argument("--json", action="store_true", help="print the spec as JSON")
    args = parser.parse_args(argv)

    prompt = " ".join(args.prompt)
    overrides = {k: v for k, v in (("bars", args.bars), ("tempo", args.tempo))
                 if v is not None}
    spec = parse_prompt(prompt, seed=args.seed, overrides=overrides or None)
    result = render(spec, priors=load_corpus_priors(Path(args.corpus)))

    output = Path(args.output) if args.output else Path(f"middaw-{spec.seed}.mid")
    output.write_bytes(result.midi)

    if args.json:
        import json
        print(json.dumps(result.to_dict(), indent=2))
    else:
        print(spec.summary())
        print("  " + "  ".join(c["symbol"] for c in result.chords[:8]))
        if spec.unmatched_terms:
            print("  not understood: " + ", ".join(spec.unmatched_terms))
        print(f"  wrote {output} ({len(result.midi)} bytes, seed {spec.seed})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
