"""The `MusicSpec` - the structured object that sits between prompt and MIDI.

The spec is the contract of the whole system. A prompt is parsed *into* a spec,
a spec is rendered *into* MIDI, and a labelled corpus entry is described with
the same vocabulary the spec uses. Keeping that one representation means the
dataset labels, the prompt vocabulary and the generator controls never drift
apart.
"""

from __future__ import annotations

from dataclasses import dataclass, field, asdict

from middaw.chance import Chances
from middaw.theory import is_minor
from middaw.scaleview import key_for

DEFAULT_TICKS_PER_BEAT = 480


@dataclass
class MusicSpec:
    prompt: str = ""
    seed: int = 0

    # --- core musical frame ---
    tonic: int = 0                       # pitch class, 0 = C
    mode: str = "major"
    tempo: int = 100                     # BPM
    meter: tuple[int, int] = (4, 4)
    bars: int = 16

    # --- content controls (0..1 unless noted) ---
    density: float = 0.5                 # note events per beat, scaled
    swing: float = 0.0                   # 0 = straight, 0.33 = triplet swing
    extensions: float = 0.2              # probability of 7th/9th colouring
    register: int = 0                    # -4..+4, 1 unit = a minor third
    velocity: int = 78                   # base velocity
    humanize: float = 1.0                # multiplier on timing/velocity noise

    # --- arrangement ---
    progression: list[str] = field(default_factory=lambda: ["I", "V", "vi", "IV"])
    progression_labels: list[str] = field(default_factory=list)
    chromaticism: float = 0.25
    ornament: float = 0.35
    pattern: str = "block"               # accompaniment figure
    harmony: str = "chords"              # chords | ostinato | arpeggio
    chances: Chances = field(default_factory=Chances)

    # --- provenance of the interpretation ---
    genres: list[str] = field(default_factory=list)
    moods: list[str] = field(default_factory=list)
    descriptors: list[str] = field(default_factory=list)
    scales: list[str] = field(default_factory=list)
    forms: list[str] = field(default_factory=list)
    voices: list[str] = field(default_factory=lambda: ["melody", "countermelody",
                                                      "harmony", "bass"])
    form: str = ""
    form_name: str = ""
    matched_terms: list[str] = field(default_factory=list)
    unmatched_terms: list[str] = field(default_factory=list)
    corpus_sources: list[str] = field(default_factory=list)

    tonic_spelling: str | None = None    # honour how the user wrote the key
    ticks_per_beat: int = DEFAULT_TICKS_PER_BEAT

    # ------------------------------------------------------------------
    @property
    def beats_per_bar(self) -> float:
        num, den = self.meter
        return num * 4.0 / den

    @property
    def ticks_per_bar(self) -> int:
        return int(round(self.beats_per_bar * self.ticks_per_beat))

    @property
    def key_name(self) -> str:
        return self.key().label

    def key(self):
        """The spelled key, from the ScaleView port."""
        return key_for(self.tonic, self.mode, self.tonic_spelling)

    @property
    def is_minor(self) -> bool:
        return is_minor(self.mode)

    @property
    def duration_seconds(self) -> float:
        return self.bars * self.beats_per_bar * 60.0 / self.tempo

    def clamp(self) -> "MusicSpec":
        self.tempo = int(max(30, min(240, self.tempo)))
        self.bars = int(max(1, min(128, self.bars)))
        self.density = max(0.12, min(1.0, self.density))
        self.swing = max(0.0, min(0.5, self.swing))
        self.extensions = max(0.0, min(1.0, self.extensions))
        self.register = int(max(-4, min(4, self.register)))
        self.velocity = int(max(20, min(120, self.velocity)))
        self.humanize = max(0.0, min(2.0, self.humanize))
        self.chromaticism = max(0.0, min(1.0, self.chromaticism))
        self.ornament = max(0.0, min(1.0, self.ornament))
        self.chances.clamp()
        self.tonic %= 12
        return self

    def to_dict(self) -> dict:
        data = asdict(self)
        data["meter"] = f"{self.meter[0]}/{self.meter[1]}"
        data["key"] = self.key_name
        data["duration_seconds"] = round(self.duration_seconds, 2)
        return data

    def summary(self) -> str:
        """One line a human can sanity-check the interpretation against."""
        bits = [
            self.key_name,
            f"{self.tempo} BPM",
            f"{self.meter[0]}/{self.meter[1]}",
            f"{self.bars} bars",
            (f"{self.form_name.replace('_', ' ')}: {self.form}"
             if self.form else ""),
            " ".join(self.progression[:8]) + ("..." if len(self.progression) > 8 else ""),
        ]
        tags = self.genres + self.moods
        if tags:
            bits.insert(0, ", ".join(tags))
        return " | ".join(b for b in bits if b)
