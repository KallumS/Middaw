"""Loads `data/vocab/tags.json` and turns tag ids into generator priors."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path

VOCAB_PATH = Path(__file__).resolve().parent.parent / "data" / "vocab" / "tags.json"

_WORD_RE = re.compile(r"[a-z0-9#&+/-]+")


@dataclass
class Priors:
    """Accumulated generator settings derived from a set of tags."""

    tempo_low: float = 88.0
    tempo_high: float = 112.0
    tempo_scale: float = 1.0
    modes: dict[str, float] = field(default_factory=dict)
    meters: dict[str, float] = field(default_factory=dict)
    progressions: list[tuple[tuple[str, ...], float]] = field(default_factory=list)
    patterns: dict[str, float] = field(default_factory=dict)
    density: float = 0.5
    swing: float = 0.0
    extensions: float = 0.2
    register: float = 0.0
    velocity: float = 78.0
    humanize: float = 1.0
    ornament: float = 0.35        # appetite for non-chord tones
    chromaticism: float = 0.25    # appetite for secondary/substitute dominants
    functional: float = 0.5       # chance of writing the progression from function

    def apply_genre(self, entry: dict, weight: float = 1.0) -> None:
        lo, hi = entry.get("tempo", [self.tempo_low, self.tempo_high])
        # Genres overlap by intersecting tempo windows where they can.
        self.tempo_low = (self.tempo_low * (1 - weight)) + lo * weight
        self.tempo_high = (self.tempo_high * (1 - weight)) + hi * weight
        for mode, w in entry.get("modes", {}).items():
            self.modes[mode] = self.modes.get(mode, 0.0) + w * weight
        for meter, w in entry.get("meters", {}).items():
            self.meters[meter] = self.meters.get(meter, 0.0) + w * weight
        for prog in entry.get("progressions", []):
            self.progressions.append((tuple(prog["c"]), prog.get("w", 1) * weight))
        for pattern, w in entry.get("patterns", {}).items():
            self.patterns[pattern] = self.patterns.get(pattern, 0.0) + w * weight
        for key in ("density", "swing", "extensions", "register", "velocity",
                    "chromaticism", "functional", "ornament"):
            if key in entry:
                current = getattr(self, key)
                setattr(self, key, current * (1 - weight) + entry[key] * weight)

    def apply_modifier(self, entry: dict) -> None:
        """Moods and descriptors nudge an existing prior rather than replacing it."""
        for mode, w in entry.get("modes", {}).items():
            self.modes[mode] = self.modes.get(mode, 0.0) + w
        for meter, w in entry.get("meters", {}).items():
            self.meters[meter] = self.meters.get(meter, 0.0) + w
        for prog in entry.get("progressions", []):
            self.progressions.append((tuple(prog["c"]), prog.get("w", 1)))
        for pattern, w in entry.get("patterns", {}).items():
            self.patterns[pattern] = self.patterns.get(pattern, 0.0) + w
        self.tempo_scale *= entry.get("tempo_scale", 1.0)
        self.density += entry.get("density_delta", 0.0)
        self.extensions += entry.get("extensions_delta", 0.0)
        self.register += entry.get("register_delta", 0.0)
        self.velocity += entry.get("velocity_delta", 0.0)
        self.chromaticism += entry.get("chromaticism_delta", 0.0)
        self.ornament += entry.get("ornament_delta", 0.0)
        if "swing" in entry:
            self.swing = entry["swing"]
        self.humanize *= entry.get("humanize_scale", 1.0)


@dataclass(frozen=True)
class Match:
    kind: str      # "genre" | "mood" | "descriptor" | "role"
    tag: str
    phrase: str
    start: int
    end: int


class Vocabulary:
    def __init__(self, data: dict):
        self.data = data
        self.genres = data.get("genres", {})
        self.moods = data.get("moods", {})
        self.descriptors = data.get("descriptors", {})
        self.roles = data.get("roles", {})
        self.scales = data.get("scales", {})
        self.forms = data.get("forms", {})
        self.voices = data.get("voices", {})
        self._phrases = self._build_phrase_index()

    def _build_phrase_index(self) -> list[tuple[str, str, str]]:
        phrases: list[tuple[str, str, str]] = []
        for kind, group in (
            ("genre", self.genres),
            ("mood", self.moods),
            ("descriptor", self.descriptors),
            ("role", self.roles),
            ("scale", self.scales),
            ("form", self.forms),
            ("voice", self.voices),
        ):
            for tag, entry in group.items():
                terms = set(entry.get("synonyms", []))
                terms.add(tag.replace("_", " "))
                label = entry.get("label")
                if label:
                    terms.add(label.lower())
                for term in terms:
                    phrase = normalise(term)
                    if phrase:
                        phrases.append((phrase, kind, tag))
        # Longest phrase wins, so "lo-fi" never loses to a one-word overlap.
        phrases.sort(key=lambda p: (-len(p[0].split()), -len(p[0])))
        return phrases

    def all_tags(self) -> dict[str, list[str]]:
        return {
            "genres": sorted(self.genres),
            "moods": sorted(self.moods),
            "descriptors": sorted(self.descriptors),
            "roles": sorted(self.roles),
            "scales": sorted(self.scales),
            "forms": sorted(self.forms),
            "voices": sorted(self.voices),
        }

    def is_known(self, kind: str, tag: str) -> bool:
        group = {"genre": self.genres, "mood": self.moods,
                 "descriptor": self.descriptors, "role": self.roles,
                 "scale": self.scales, "form": self.forms,
                 "voice": self.voices}.get(kind, {})
        return tag in group

    def find(self, text: str) -> list[Match]:
        """Greedy longest-first phrase match over normalised text."""
        haystack = f" {normalise(text)} "
        taken = [False] * len(haystack)
        matches: list[Match] = []
        for phrase, kind, tag in self._phrases:
            needle = f" {phrase} "
            start = haystack.find(needle)
            while start != -1:
                # Claim only the phrase itself, not its boundary spaces, so
                # "celtic jig" can match both "celtic" and "jig".
                span = range(start + 1, start + len(needle) - 1)
                if not any(taken[i] for i in span):
                    for i in span:
                        taken[i] = True
                    matches.append(Match(kind, tag, phrase, start, start + len(needle)))
                    break
                start = haystack.find(needle, start + 1)
        matches.sort(key=lambda m: m.start)
        return matches

    def priors_for(self, matches: list[Match]) -> Priors:
        priors = Priors()
        genres = _dedupe_by_tag([m for m in matches if m.kind == "genre"])
        if genres:
            share = 1.0 / len(genres)
            for i, m in enumerate(genres):
                # First genre carries the frame; later ones blend in.
                priors.apply_genre(self.genres[m.tag], 1.0 if i == 0 else share)
        else:
            priors.modes = {"major": 3, "minor": 3, "dorian": 1, "mixolydian": 1}
            priors.meters = {"4/4": 10, "3/4": 2}
            priors.patterns = {"block": 3, "arpeggio_up": 2, "arpeggio_updown": 2, "ballad": 1}
            priors.progressions = [
                (("I", "V", "vi", "IV"), 3),
                (("i", "bVI", "bIII", "bVII"), 3),
                (("I", "vi", "IV", "V"), 2),
                (("i", "iv", "V7", "i"), 2),
            ]
        for m in _dedupe_by_tag(matches):
            if m.kind == "mood":
                priors.apply_modifier(self.moods[m.tag])
            elif m.kind == "descriptor":
                priors.apply_modifier(self.descriptors[m.tag])
        return priors


def _dedupe_by_tag(matches: list[Match]) -> list[Match]:
    """Two synonyms of one tag in a prompt ("bebop jazz") must not count twice."""
    seen: set[tuple[str, str]] = set()
    out: list[Match] = []
    for m in matches:
        key = (m.kind, m.tag)
        if key not in seen:
            seen.add(key)
            out.append(m)
    return out


def normalise(text: str) -> str:
    text = text.lower().replace("&", " and ").replace("_", " ")
    text = text.replace("-", " ")
    words = _WORD_RE.findall(text)
    return " ".join(words)


@lru_cache(maxsize=1)
def load_vocabulary(path: str | None = None) -> Vocabulary:
    target = Path(path) if path else VOCAB_PATH
    with open(target, "r", encoding="utf-8") as fh:
        return Vocabulary(json.load(fh))
