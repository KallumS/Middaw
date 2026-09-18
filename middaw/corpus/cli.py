"""`python -m middaw.corpus` - ingest, validate and inspect the dataset."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from datetime import date
from pathlib import Path

from middaw.corpus.analyse import analyse_file
from middaw.corpus.schema import SCHEMA_VERSION, Entry, validate_entry
from middaw.corpus.stats import load_corpus_priors, load_manifest
from middaw.vocab import load_vocabulary

MANIFEST_NAME = "manifest.json"


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as fh:
        for block in iter(lambda: fh.read(65536), b""):
            digest.update(block)
    return digest.hexdigest()


def _write_manifest(directory: Path, entries: list[Entry]) -> None:
    payload = {
        "schema_version": SCHEMA_VERSION,
        "generated": date.today().isoformat(),
        "entries": [e.to_dict() for e in sorted(entries, key=lambda e: e.id)],
    }
    (directory / MANIFEST_NAME).write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def cmd_ingest(args) -> int:
    """Add or refresh the derived labels for every MIDI file in the corpus.

    Provenance and tags are never invented here: a new file arrives with an
    empty provenance block that will fail `validate` until a human fills it in.
    That is the point - it makes an unlicensed file impossible to forget about.
    """
    directory = Path(args.directory)
    directory.mkdir(parents=True, exist_ok=True)
    existing = {entry.id: entry for entry in load_manifest(directory)}

    files = sorted(p for p in directory.rglob("*")
                   if p.suffix.lower() in (".mid", ".midi"))
    added = refreshed = failed = 0
    for path in files:
        entry_id = path.relative_to(directory).as_posix().rsplit(".", 1)[0]
        entry_id = entry_id.lower().replace("/", "-").replace(" ", "-")
        entry = existing.get(entry_id)
        if entry is None:
            entry = Entry(id=entry_id, file=path.relative_to(directory).as_posix())
            existing[entry_id] = entry
            added += 1
        else:
            refreshed += 1
        try:
            entry.derived = analyse_file(path)
        except Exception as error:                       # a bad file is data, not a crash
            print(f"  ! {path.name}: {error}", file=sys.stderr)
            failed += 1
            continue
        entry.provenance.setdefault("sha256", _sha256(path))
        entry.derived["analysed_on"] = date.today().isoformat()

    _write_manifest(directory, list(existing.values()))
    print(f"ingested {len(files)} file(s): {added} new, {refreshed} refreshed, "
          f"{failed} unreadable")
    if added:
        print("  new entries have no provenance yet - `validate` will list them")
    return 0


def cmd_validate(args) -> int:
    directory = Path(args.directory)
    entries = load_manifest(directory)
    if not entries:
        print(f"no manifest in {directory} (nothing to validate)")
        return 0
    vocab = load_vocabulary()

    bad = 0
    for entry in entries:
        problems = validate_entry(entry, vocab)
        if problems:
            bad += 1
            print(f"{entry.id}:")
            for problem in problems:
                print(f"  - {problem}")
    usable = len(entries) - bad
    print(f"\n{usable}/{len(entries)} entries are usable; "
          f"{sum(1 for e in entries if e.commercial_ok)} cleared for commercial use")
    return 1 if bad and args.strict else 0


def cmd_stats(args) -> int:
    priors = load_corpus_priors(Path(args.directory),
                               commercial_only=not args.include_restricted)
    described = priors.describe()
    print(json.dumps(described, indent=2))
    if described["entries"]:
        for tag in described["tags"][:10]:
            progressions = priors.progressions_for([tag], limit=3)
            if progressions:
                print(f"\n{tag}:")
                for chords, weight in progressions:
                    print(f"  {' '.join(chords):32s} {weight:.2f}")
    return 0


def cmd_show(args) -> int:
    print(json.dumps(analyse_file(Path(args.file)), indent=2))
    return 0


def cmd_measure(args) -> int:
    """Measure the analyser against scores somebody else wrote.

    Points at a folder of MusicXML (and any RomanText analyses beside them),
    reports how close we are, and reads nothing into the corpus: measuring is
    not ingesting, and these files are not ours to pool. See docs/DATASET.md.
    """
    from middaw.corpus.measure import format_report, run

    folder = Path(args.folder)
    if not folder.is_dir():
        print(f"{folder}: not a directory", file=sys.stderr)
        return 1
    report = run(folder, limit=args.limit, style=args.style, seed=args.seed)
    if not report["scores"]:
        print(f"no scores found in {folder}", file=sys.stderr)
        return 1
    print(format_report(report))
    if args.json:
        Path(args.json).write_text(
            json.dumps(_jsonable(report), indent=2) + "\n", encoding="utf-8")
        print(f"\nwrote {args.json}")
    return 0


def _jsonable(report: dict) -> dict:
    """The report with its dataclasses and counters flattened."""
    from dataclasses import asdict, is_dataclass

    def convert(value):
        if is_dataclass(value):
            return convert(asdict(value))
        if isinstance(value, dict):
            return {str(k): convert(v) for k, v in value.items()}
        if isinstance(value, (list, tuple)):
            return [convert(v) for v in value]
        return value

    return convert(report)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="middaw.corpus")
    parser.add_argument("--directory", "-d", default="data/corpus")
    sub = parser.add_subparsers(dest="command", required=True)

    ingest = sub.add_parser("ingest", help="derive labels for every MIDI file")
    ingest.set_defaults(func=cmd_ingest)

    validate = sub.add_parser("validate", help="check provenance and tags")
    validate.add_argument("--strict", action="store_true",
                          help="exit non-zero if anything is wrong")
    validate.set_defaults(func=cmd_validate)

    stats = sub.add_parser("stats", help="what the corpus teaches the generator")
    stats.add_argument("--include-restricted", action="store_true")
    stats.set_defaults(func=cmd_stats)

    show = sub.add_parser("show", help="derived labels for one file")
    show.add_argument("file")
    show.set_defaults(func=cmd_show)

    measure = sub.add_parser(
        "measure", help="check the analyser against scores and human analyses")
    measure.add_argument("folder", help="a folder of MusicXML, and any "
                                        "RomanText analyses beside them")
    measure.add_argument("--limit", type=int, default=None)
    measure.add_argument("--style", default="hymn",
                         help="the style to generate for the melody comparison")
    measure.add_argument("--seed", type=int, default=1)
    measure.add_argument("--json", help="also write the full report here")
    measure.set_defaults(func=cmd_measure)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
