"""The corpus label schema.

Three tiers, and the split between them is the whole point:

1. `provenance` - **required, human-entered, never guessed.** Where the file
   came from and why we are allowed to use it. A file without a complete,
   verified provenance block is not in the dataset, full stop; the check is
   mechanical so that "we'll tidy the licences later" cannot happen.
2. `derived` - **computed, never typed.** Key, tempo, meter, density, chord
   symbols and so on, all read off the notes by `middaw.corpus.analyse`.
   Recomputable from the file at any time, so it is never stale and never
   inconsistent between annotators.
3. `tags` - **subjective, from a closed vocabulary.** Genre, mood, descriptors
   and roles, every value an id in `data/vocab/tags.json`. Free text is
   rejected at ingest, because a dataset with "chill", "chilled", "chillout"
   and "chill vibes" in it cannot be queried and quietly stops being one
   dataset at all.

Tier 3 uses the same ids the prompt parser matches, so every label is
reachable from a prompt and every prompt word has somewhere to look.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any

SCHEMA_VERSION = 1

# Licences that permit commercial use without a share-alike obligation on the
# model output. Anything else is flagged and kept out of the default training
# split rather than silently mixed in.
PERMISSIVE_LICENCES = {
    "PD", "public-domain", "CC0-1.0", "CC-BY-4.0", "CC-BY-3.0", "MIT",
    "owned-original",
}
NON_COMMERCIAL_LICENCES = {"CC-BY-NC-4.0", "CC-BY-NC-SA-4.0", "CC-BY-NC-SA-3.0"}
SHARE_ALIKE_LICENCES = {"CC-BY-SA-4.0", "CC-BY-SA-3.0", "GPL-3.0"}

KNOWN_LICENCES = PERMISSIVE_LICENCES | NON_COMMERCIAL_LICENCES | SHARE_ALIKE_LICENCES

REQUIRED_PROVENANCE = ("source", "license", "rights_basis", "verified_by", "verified_on")
ANNOTATOR_KINDS = {"human", "heuristic", "model", "source-metadata"}

_ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]{2,79}$")
_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


@dataclass
class Entry:
    id: str
    file: str
    provenance: dict[str, Any] = field(default_factory=dict)
    derived: dict[str, Any] = field(default_factory=dict)
    tags: dict[str, list[str]] = field(default_factory=dict)
    annotations: list[dict[str, Any]] = field(default_factory=list)
    schema_version: int = SCHEMA_VERSION

    @classmethod
    def from_dict(cls, data: dict) -> "Entry":
        return cls(
            id=data.get("id", ""),
            file=data.get("file", ""),
            provenance=data.get("provenance", {}) or {},
            derived=data.get("derived", {}) or {},
            tags=data.get("tags", {}) or {},
            annotations=data.get("annotations", []) or [],
            schema_version=data.get("schema_version", SCHEMA_VERSION),
        )

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "schema_version": self.schema_version,
            "file": self.file,
            "provenance": self.provenance,
            "derived": self.derived,
            "tags": self.tags,
            "annotations": self.annotations,
        }

    @property
    def licence(self) -> str:
        return str(self.provenance.get("license", ""))

    @property
    def commercial_ok(self) -> bool:
        return self.licence in PERMISSIVE_LICENCES

    def all_tags(self) -> list[str]:
        return [tag for values in self.tags.values() for tag in values]


def validate_entry(entry: Entry | dict, vocab=None) -> list[str]:
    """Return a list of problems. An empty list means the entry may be used."""
    if isinstance(entry, dict):
        entry = Entry.from_dict(entry)
    problems: list[str] = []

    if not _ID_RE.match(entry.id or ""):
        problems.append(f"id {entry.id!r} must be lowercase [a-z0-9._-], 3-80 chars")
    if not entry.file:
        problems.append("file is required")
    if entry.schema_version != SCHEMA_VERSION:
        problems.append(f"schema_version {entry.schema_version} != {SCHEMA_VERSION}")

    # --- tier 1: provenance is not optional ---
    for key in REQUIRED_PROVENANCE:
        if not entry.provenance.get(key):
            problems.append(f"provenance.{key} is required")
    licence = entry.licence
    if licence and licence not in KNOWN_LICENCES:
        problems.append(
            f"license {licence!r} is not in the known set; add it to "
            "PERMISSIVE_LICENCES, NON_COMMERCIAL_LICENCES or SHARE_ALIKE_LICENCES "
            "with a decision recorded, rather than leaving it unclassified"
        )
    verified_on = entry.provenance.get("verified_on")
    if verified_on and not _DATE_RE.match(str(verified_on)):
        problems.append("provenance.verified_on must be YYYY-MM-DD")
    if entry.provenance.get("composer_died") is None and licence in (
            "PD", "public-domain"):
        problems.append(
            "a public-domain claim needs provenance.composer_died so the claim "
            "can be re-checked against a jurisdiction later"
        )
    if not entry.provenance.get("sequencer"):
        problems.append(
            "provenance.sequencer is required: a MIDI file is a separate "
            "copyrightable work from the composition it transcribes"
        )

    # --- tier 3: tags must come from the vocabulary ---
    if vocab is not None:
        groups = {"genres": "genre", "moods": "mood",
                  "descriptors": "descriptor", "roles": "role",
                  "voices": "voice"}
        for group, values in entry.tags.items():
            if group not in groups:
                problems.append(f"unknown tag group {group!r}")
                continue
            if not isinstance(values, list):
                problems.append(f"tags.{group} must be a list")
                continue
            for value in values:
                if not vocab.is_known(groups[group], value):
                    problems.append(
                        f"tags.{group} value {value!r} is not in data/vocab/tags.json"
                    )

    for annotation in entry.annotations:
        by = annotation.get("by")
        if by not in ANNOTATOR_KINDS:
            problems.append(f"annotation.by {by!r} must be one of {sorted(ANNOTATOR_KINDS)}")
        confidence = annotation.get("confidence")
        if confidence is not None and not 0.0 <= float(confidence) <= 1.0:
            problems.append("annotation.confidence must be between 0 and 1")

    return problems
