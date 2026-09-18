#!/usr/bin/env python3
"""Measure drum feel from a folder of drum MIDI, and print it as a table.

Written for the Groove MIDI Dataset (CC BY 4.0), which labels every file with
a style and whether it is a beat or a fill. Nothing from the corpus is copied
into Middaw: what crosses over is a handful of numbers, which go into
`docs/MEASUREMENTS.md` and `middaw/drums.py`.

    python3 tools/measure_groove.py <folder-with-info.csv>

This is a tool, not part of the generator, and it is the only thing in the
repository that expects a corpus to exist.
"""

from __future__ import annotations

import collections
import csv
import statistics
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from middaw.drums import load_kit                          # noqa: E402
from middaw.midi import read_midi                          # noqa: E402


def classify(pitch: int) -> str | None:
    return load_kit()["classes"].get(str(pitch))


def grid_phase(onsets: list[float], divisions: int = 4) -> float:
    """Where the bar actually starts in this performance.

    A recorded take does not begin on beat zero - there is a count-in, and the
    drummer starts when they start. Measuring microtiming without finding the
    grid first measures the offset of the recording, which is how you end up
    reporting that every drummer on earth rushes by the same amount.
    """
    if not onsets:
        return 0.0
    step = 1.0 / divisions
    best, best_error = 0.0, None
    for candidate in range(100):
        phase = candidate / 100.0 * step
        error = 0.0
        for onset in onsets:
            position = (onset - phase) / step
            error += abs(position - round(position))
        if best_error is None or error < best_error:
            best, best_error = phase, error
    return best


def beat_offset(onsets: list[tuple[float, str]], step: float = 0.25) -> int:
    """Which of the four sixteenths in a beat is the beat itself.

    Aligning to a sixteenth grid still leaves four ways round it. Kicks and
    snares land on beats more often than between them in every style here, so
    the rotation that gathers the most of them on multiples of four is the one
    that has found the beat. Without this the on-beat and off-beat velocities
    are a coin toss, and they are the whole point of the measurement.
    """
    weight = [0.0, 0.0, 0.0, 0.0]
    for onset, name in onsets:
        if name not in ("kick", "snare"):
            continue
        position = int(round(onset / step)) % 4
        weight[position] += 1
    return max(range(4), key=lambda r: weight[r])


def measure(folder: Path, limit: int | None = None) -> dict:
    rows = [r for r in csv.DictReader(open(folder / "info.csv"))
            if r["beat_type"] == "beat" and r["time_signature"] == "4-4"]
    if limit:
        rows = rows[:limit]

    velocity = collections.defaultdict(list)
    on_beat = collections.defaultdict(list)
    off_beat = collections.defaultdict(list)
    timing = collections.defaultdict(list)
    per_style = collections.defaultdict(
        lambda: {"swing": [], "ghost": 0, "snare": 0, "files": 0})

    for row in rows:
        try:
            midi = read_midi(folder / row["midi_filename"])
        except Exception:                                   # noqa: BLE001
            continue
        style = row["style"].split("/")[0]
        per_style[style]["files"] += 1
        phase = grid_phase([n.start for n in midi.notes])
        for note in midi.notes:
            note.start -= phase
        rotation = beat_offset([(n.start, classify(n.pitch)) for n in midi.notes])
        for note in midi.notes:
            note.start -= rotation * 0.25
            name = classify(note.pitch)
            if not name:
                continue
            velocity[name].append(note.velocity)
            position = (note.start % 4.0) * 4               # in sixteenths
            nearest = round(position)
            timing[name].append(position - nearest)
            (on_beat if nearest % 4 == 0 else off_beat)[name].append(note.velocity)
            if name in ("ride", "hat"):
                per_style[style].setdefault("timekeeper", []).append(note.start)
            if name == "snare":
                per_style[style]["snare"] += 1
                per_style[style]["ghost"] += note.velocity < 45

    for style, d in per_style.items():
        d["swing"] = _swing_points(d.pop("timekeeper", []))
    return {"velocity": velocity, "on_beat": on_beat, "off_beat": off_beat,
            "timing": timing, "styles": per_style, "files": len(rows)}


def _swing_points(onsets: list[float]) -> list[float]:
    """Where the second of two hits in a beat lands, as a fraction of the beat.

    Only beats played in *two* - a ride going ding, ding-a - say anything about
    swing. Sixteenth-note hi-hats say nothing, and counting them drags every
    style towards fifty per cent whether it swings or not.
    """
    by_beat: dict[int, list[float]] = {}
    for onset in onsets:
        by_beat.setdefault(int(onset), []).append(onset % 1.0)
    points = []
    for beat, positions in by_beat.items():
        positions.sort()
        if len(positions) == 2 and positions[0] < 0.2:
            points.append(positions[1])
    return points


def report(data: dict) -> str:
    lines = [f"measured {data['files']} beats", "",
             f"{'class':9}{'hits':>8}{'velocity':>10}{'on beat':>9}"
             f"{'off beat':>10}{'timing, 16ths':>16}"]
    for name, hits in sorted(data["velocity"].items(),
                             key=lambda kv: -len(kv[1])):
        if len(hits) < 200:
            continue
        lines.append(
            f"{name:9}{len(hits):>8}{statistics.mean(hits):>10.1f}"
            f"{statistics.mean(data['on_beat'][name]):>9.1f}"
            f"{statistics.mean(data['off_beat'][name]):>10.1f}"
            f"{statistics.mean(data['timing'][name]):>+11.3f}"
            f" ±{statistics.pstdev(data['timing'][name]):.3f}")

    lines += ["", f"{'style':14}{'files':>7}{'beats in two':>14}{'swing':>8}"
              f"{'swung':>8}{'ghosted snares':>17}"]
    for style, d in sorted(data["styles"].items(), key=lambda kv: -kv[1]["files"]):
        swing = d["swing"]
        if len(swing) < 50:
            continue
        swung = sum(1 for point in swing if point > 0.56) / len(swing)
        lines.append(f"{style:14}{d['files']:>7}{len(swing):>14}"
                     f"{statistics.median(swing):>8.0%}{swung:>8.0%}"
                     f"{d['ghost'] / max(1, d['snare']):>16.0%}")
    return "\n".join(lines)


# --------------------------------------------------------------------------
# And the other direction: what does Middaw play?
# --------------------------------------------------------------------------

def corpus_grid(folder: Path, style: str, limit: int = 60) -> dict:
    """Hits per sixteenth, per instrument, for one style of real playing."""
    rows = [r for r in csv.DictReader(open(folder / "info.csv"))
            if r["beat_type"] == "beat" and r["time_signature"] == "4-4"
            and r["style"].split("/")[0] == style][:limit]
    grid: dict[str, collections.Counter] = {}
    bars = 0
    for row in rows:
        try:
            midi = read_midi(folder / row["midi_filename"])
        except Exception:                                   # noqa: BLE001
            continue
        phase = grid_phase([n.start for n in midi.notes])
        for note in midi.notes:
            note.start -= phase
        rotation = beat_offset([(n.start, classify(n.pitch)) for n in midi.notes])
        span = max((n.end for n in midi.notes), default=0)
        bars += max(1, int(span // 4))
        for note in midi.notes:
            name = classify(note.pitch)
            if not name:
                continue
            position = int(round((note.start - rotation * 0.25) * 4)) % 16
            grid.setdefault(name, collections.Counter())[position] += 1
    return {"grid": grid, "bars": max(1, bars), "files": len(rows)}


def compare(folder: Path, style: str, prompt: str, seeds: int = 8) -> str:
    """Print the real grid and ours for the same style, side by side."""
    from middaw.drums import grid_of
    from middaw.prompt import parse_prompt
    from middaw.render import render

    real = corpus_grid(folder, style)
    ours: dict[str, collections.Counter] = {}
    bars = 0
    for seed in range(seeds):
        result = render(parse_prompt(prompt + ", 4/4", seed=seed))
        drums = [t for t in result.song.tracks if t.role == "drums"]
        if not drums:
            continue
        bars += result.spec.bars
        for name, counts in grid_of(drums[0].notes,
                                    result.spec.beats_per_bar).items():
            ours.setdefault(name, collections.Counter()).update(counts)

    def row(counts, total, threshold=0.35):
        marks = "".join("X" if counts[s] > total * threshold else
                        "x" if counts[s] > total * 0.08 else "."
                        for s in range(16))
        return f"|{marks[:4]}|{marks[4:8]}|{marks[8:12]}|{marks[12:]}|"

    lines = [f"{style} ({real['files']} performances, {real['bars']} bars) "
             f"vs \"{prompt}\" ({bars} bars)"]
    for name in ("kick", "snare", "hat", "pedalhat", "ride", "clap", "rim"):
        if name not in real["grid"] and name not in ours:
            continue
        lines.append(f"  {name:6} real {row(real['grid'].get(name, collections.Counter()), real['bars'])}")
        lines.append(f"  {'':6} ours {row(ours.get(name, collections.Counter()), max(1, bars))}")
    return "\n".join(lines)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        raise SystemExit(1)
    folder = Path(sys.argv[1])
    if len(sys.argv) >= 4:
        print(compare(folder, sys.argv[2], sys.argv[3]))
    else:
        print(report(measure(folder)))
