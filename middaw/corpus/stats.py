"""Turn the labelled corpus into generator priors.

This is where the dataset earns its keep. For a given set of tags it returns
the melodic step distribution, the rhythm cells and the chord progressions
that files carrying those tags actually use, blended over the built-in
defaults rather than replacing them - so one lo-fi file nudges the generator
and two hundred steer it, with nothing special-cased in between.

With no corpus present every lookup returns the defaults unchanged, which is
why the app works before a single file has been sourced.
"""

from __future__ import annotations

import json
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path

from middaw.corpus.schema import Entry

# How far the corpus can pull a distribution away from the built-in default,
# and how many observations it takes to get there.
MAX_INFLUENCE = 0.75
HALF_INFLUENCE_AT = 40


@dataclass
class CorpusPriors:
    entries: int = 0
    commercial_entries: int = 0
    interval_counts: dict[str, Counter] = field(default_factory=lambda: defaultdict(Counter))
    rhythm_counts: dict[str, Counter] = field(default_factory=lambda: defaultdict(Counter))
    progression_counts: dict[str, Counter] = field(default_factory=lambda: defaultdict(Counter))
    tempo_samples: dict[str, list[float]] = field(default_factory=lambda: defaultdict(list))
    sources: dict[str, list[str]] = field(default_factory=lambda: defaultdict(list))

    # ------------------------------------------------------------ building --
    def add(self, entry: Entry, commercial_only: bool = True) -> None:
        if commercial_only and not entry.commercial_ok:
            return
        derived = entry.derived or {}
        if not derived:
            return
        self.entries += 1
        if entry.commercial_ok:
            self.commercial_entries += 1

        tags = ["*"] + entry.all_tags()
        for tag in tags:
            for step, count in (derived.get("intervals") or {}).items():
                try:
                    self.interval_counts[tag][int(step)] += int(count)
                except (TypeError, ValueError):
                    continue
            for cell, count in (derived.get("rhythm_cells") or {}).items():
                self.rhythm_counts[tag][cell] += int(count)
            roman = [r for r in (derived.get("roman") or []) if r]
            for window in _windows(roman, 4):
                self.progression_counts[tag][window] += 1
            if derived.get("tempo"):
                self.tempo_samples[tag].append(float(derived["tempo"]))
            if len(self.sources[tag]) < 32:
                self.sources[tag].append(entry.id)

    # ------------------------------------------------------------- lookups --
    def _weight(self, counts: Counter) -> float:
        """Confidence in this tag's statistics, from how much of it we have."""
        total = sum(counts.values())
        if total <= 0:
            return 0.0
        return MAX_INFLUENCE * total / (total + HALF_INFLUENCE_AT)

    def _pooled(self, table: dict[str, Counter], tags: list[str]) -> Counter:
        pooled: Counter = Counter()
        for tag in tags or ["*"]:
            pooled.update(table.get(tag, Counter()))
        if not pooled:
            pooled.update(table.get("*", Counter()))
        return pooled

    def intervals_for(self, tags: list[str], base: dict[int, float]) -> dict[int, float]:
        counts = self._pooled(self.interval_counts, tags)
        weight = self._weight(counts)
        if weight <= 0:
            return dict(base)
        total = sum(counts.values())
        blended = {}
        for step in set(base) | set(counts):
            corpus_share = counts.get(step, 0) / total
            default_share = base.get(step, 0.0) / max(1e-9, sum(base.values()))
            blended[step] = (1 - weight) * default_share + weight * corpus_share
        return {k: v for k, v in blended.items() if v > 1e-6}

    def rhythm_bias_for(self, tags: list[str]) -> dict[tuple[float, ...], float]:
        """Multiplicative nudges on the built-in cell weights."""
        counts = self._pooled(self.rhythm_counts, tags)
        weight = self._weight(counts)
        if weight <= 0:
            return {}
        total = sum(counts.values())
        bias: dict[tuple[float, ...], float] = {}
        for cell, count in counts.items():
            try:
                key = tuple(float(part) for part in cell.split(","))
            except ValueError:
                continue
            bias[key] = weight * (count / total) * len(counts)
        return bias

    def progressions_for(self, tags: list[str], limit: int = 8) -> list[tuple[tuple[str, ...], float]]:
        counts = self._pooled(self.progression_counts, tags)
        weight = self._weight(counts)
        if weight <= 0:
            return []
        top = counts.most_common(limit)
        scale = weight * 6.0
        return [(chords, scale * count / top[0][1]) for chords, count in top]

    def sources_for(self, tags: list[str], limit: int = 12) -> list[str]:
        seen: list[str] = []
        for tag in tags or ["*"]:
            for source in self.sources.get(tag, []):
                if source not in seen:
                    seen.append(source)
        return seen[:limit]

    def describe(self) -> dict:
        return {
            "entries": self.entries,
            "commercial_entries": self.commercial_entries,
            "tags": sorted(t for t in self.interval_counts if t != "*"),
            "intervals": sum(sum(c.values()) for c in self.interval_counts.values()),
            "progressions": sum(sum(c.values()) for c in self.progression_counts.values()),
        }


def _windows(items: list[str], size: int) -> list[tuple[str, ...]]:
    if len(items) < size:
        return []
    return [tuple(items[i:i + size]) for i in range(0, len(items) - size + 1, size)]


def load_manifest(directory: Path) -> list[Entry]:
    manifest = Path(directory) / "manifest.json"
    if not manifest.is_file():
        return []
    try:
        data = json.loads(manifest.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return []
    return [Entry.from_dict(item) for item in data.get("entries", [])]


def load_corpus_priors(directory: Path, commercial_only: bool = True) -> CorpusPriors:
    priors = CorpusPriors()
    for entry in load_manifest(directory):
        priors.add(entry, commercial_only=commercial_only)
    return priors
