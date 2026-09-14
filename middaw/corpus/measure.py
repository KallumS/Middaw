"""Measure Middaw against notated music somebody else wrote.

Every accuracy figure in this project so far was produced by generating music
and then analysing it, which measures the generator against itself. This module
measures it against scores, and against a human analyst's reading of those
scores, which is the only way to find out whether the rules are right rather
than merely consistent.

Nothing here reads a licence for you, and nothing it touches is redistributed:
it reports numbers about a folder of files, and the files stay where they are.
See `docs/DATASET.md` before pointing it at anything.
"""

from __future__ import annotations

import math
import re
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path

from middaw.corpus.analyse import detect_key, name_window, symbol_root
from middaw.corpus.notation import (Analysis, Score, parse_romantext_key,
                                    read_romantext, read_score)
from middaw.scaleview import key_for
from middaw.song import Note
from middaw.theory import NOTE_NAMES, SCALES, parse_roman

SCORE_SUFFIXES = (".mxl", ".musicxml", ".xml", ".krn")

#: Part names that mean "this staff carries one melodic line". The top line of
#: a piano staff is not a melody - it is whichever note happens to be highest,
#: which is why measuring a song's melody against the piano part produces
#: octave leaps and a stepwise share that means nothing.
MELODY_PART_NAMES = ("soprano", "voice", "singstimme", "gesang", "stimme",
                     "chant", "canto", "melody", "vocal", "descant",
                     "violin", "violino", "flute", "oboe", "clarinet")

#: Figured bass says which inversion, not which chord. Both are stripped for
#: comparison, because a chord read from notes has no way to report one and
#: naming the wrong inversion is a different mistake from naming the wrong
#: chord.
_FIGURES_RE = re.compile(r"\d+(?:/\d+)*")


@dataclass
class KeyResult:
    name: str
    expected: tuple[int, str]
    found: tuple[int, str]
    confidence: float
    #: False when all the file gave us was a key signature. Then the only
    #: honest question is whether our tonic belongs to that collection.
    stated: bool = True
    collection: tuple[int, ...] = ()

    @property
    def in_collection(self) -> bool:
        return not self.collection or self.found[0] in self.collection

    @property
    def tonic_right(self) -> bool:
        return self.expected[0] == self.found[0]

    @property
    def exact(self) -> bool:
        return self.tonic_right and self.expected[1] == self.found[1]

    @property
    def relative(self) -> bool:
        """The most common near-miss: the relative major or minor."""
        if self.exact or self.tonic_right:
            return False
        want, got = self.expected, self.found
        return ((want[1] == "major" and got[1] == "minor"
                 and got[0] == (want[0] + 9) % 12)
                or (want[1] == "minor" and got[1] == "major"
                    and got[0] == (want[0] + 3) % 12))


@dataclass
class HarmonyResult:
    name: str
    compared: int = 0
    root_right: int = 0
    quality_right: int = 0
    unreadable: int = 0      # numerals our theory cannot express
    unnamed: int = 0         # spans our reader would not name
    transposed: int = 0      # semitones the score sits from its analysis
    disagreements: list[tuple[str, str]] = field(default_factory=list)

    @property
    def accuracy(self) -> float:
        return self.root_right / self.compared if self.compared else 0.0


def _clean_numeral(numeral: str) -> str:
    """Reduce an analyst's numeral to something `parse_roman` can read."""
    numeral = numeral.replace("ø", "o").replace("%", "o").replace("-", "b")
    parts = numeral.split("/")
    # A trailing "/V" is a tonicisation; "/3" is figured bass. Keep the first.
    kept = [parts[0]]
    for part in parts[1:]:
        if part and not part[0].isdigit():
            kept.append(part)
    return "/".join(_FIGURES_RE.sub("", part) for part in kept)


def analyst_chord(chord, default_key: tuple[int, str]):
    """The chord an analyst's numeral stands for, in absolute pitch classes."""
    key = parse_romantext_key(chord.key) or default_key
    cleaned = _clean_numeral(chord.numeral)
    if not cleaned:
        return None
    try:
        return parse_roman(cleaned, key[0], key[1])
    except ValueError:
        return None


def measure_key(score: Score, analysis: Analysis | None, name: str) -> KeyResult:
    """Ask `detect_key` for the key, and compare it with what is written.

    An analyst's key is the ground truth where there is one. Failing that, a
    file that states major or minor alongside its signature is ground truth
    too. A file that states only a signature is *not*: two sharps is D major,
    B minor and E dorian, and marking B minor wrong because the export wrote
    no mode is measuring our reader rather than our analyser.
    """
    stated = True
    expected = analysis.tonic_and_mode() if analysis is not None else None
    if expected is None:
        expected = (score.tonic, score.mode)
        stated = score.key_stated
    tonic, mode, confidence = detect_key(score.notes)
    collection = tuple(sorted((score.signature_tonic + step) % 12
                              for step in SCALES["major"]))
    return KeyResult(name=name, expected=expected, found=(tonic, mode),
                     confidence=confidence, stated=stated,
                     collection=() if stated else collection)


def measure_harmony(score: Score, analysis: Analysis, name: str) -> HarmonyResult:
    """Name the harmony over the analyst's own segmentation, and compare.

    Using the analyst's boundaries takes segmentation out of the question: the
    only thing being measured is whether we name the same chord they did over
    the same span of time.
    """
    result = HarmonyResult(name=name)
    default_key = analysis.tonic_and_mode() or (score.tonic, score.mode)
    end_of_piece = max((n.end for n in score.notes), default=0.0)

    spans = []
    for index, chord in enumerate(analysis.chords):
        start = score.measure_beat(chord.measure, chord.beat)
        if start is None:
            continue
        following = analysis.chords[index + 1:index + 2]
        finish = end_of_piece
        if following:
            nxt = score.measure_beat(following[0].measure, following[0].beat)
            if nxt is not None and nxt > start:
                finish = nxt
        if finish > start:
            spans.append((chord, start, min(finish, end_of_piece)))

    readings = []
    for chord, start, finish in spans:
        expected = analyst_chord(chord, default_key)
        if expected is None:
            result.unreadable += 1
            continue
        key = key_for(*(parse_romantext_key(chord.key) or default_key))
        named = name_window(score.notes, start, finish, key)
        root = symbol_root(named.symbol)
        if root is None:
            result.unnamed += 1
            continue
        readings.append((chord, expected, named, root))

    # A score and its analysis are sometimes editions in different keys - the
    # same chorale, written a tone or a fifth apart. That is a difference
    # between two sources, not a mistake by the analyser, so the offset is
    # detected and the comparison made in the key the score is actually in.
    result.transposed = _detected_transposition(readings)

    for chord, expected, named, root in readings:
        result.compared += 1
        expected_root = (expected.root + result.transposed) % 12
        if root == expected_root:
            result.root_right += 1
            # Quality is the third. Inversion and extensions are a different
            # question from whether the chord was heard as major or minor.
            theirs = {(pc - expected.root) % 12 for pc in expected.pitch_classes} & {3, 4}
            ours = {(pc - root) % 12 for pc in named.classes} & {3, 4}
            if theirs and theirs <= ours:
                result.quality_right += 1
        elif len(result.disagreements) < 6:
            result.disagreements.append(
                (f"{chord.key}: {chord.numeral}", named.symbol or "?"))
    return result


def _detected_transposition(readings, threshold: float = 0.6) -> int:
    """The interval the whole piece sits at, if it is not the analyst's key.

    Only a large majority counts. A handful of chords agreeing at some offset
    is what disagreement looks like; two thirds of them agreeing is a key.
    """
    if not readings:
        return 0
    offsets = Counter((root - expected.root) % 12
                      for _chord, expected, _named, root in readings)
    at_zero = offsets.get(0, 0) / len(readings)
    best, count = offsets.most_common(1)[0]
    if best and at_zero < 0.5 and count / len(readings) >= threshold:
        return best
    return 0


# --------------------------------------------------------------------------
# Melodic distributions: does what we write sit where real music sits?
# --------------------------------------------------------------------------

def melodic_profile(notes: list[Note]) -> dict:
    """Interval histogram and the two melodic rules from `docs/THEORY.md`."""
    line = sorted(notes, key=lambda n: (n.start, -n.pitch))
    top: list[Note] = []
    for note in line:
        if top and abs(note.start - top[-1].start) < 1e-6:
            continue                      # only the top note of a chord
        top.append(note)

    steps: Counter = Counter()
    leaps = recovered = 0
    for i in range(1, len(top)):
        interval = top[i].pitch - top[i - 1].pitch
        steps[max(-12, min(12, interval))] += 1
        if abs(interval) > 5 and i + 1 < len(top):
            leaps += 1
            nxt = top[i + 1].pitch - top[i].pitch
            if nxt == 0 or (nxt > 0) != (interval > 0):
                recovered += 1
    total = sum(steps.values())
    # The same four classes `middaw/chance.py` rolls, so the measurement can
    # be read straight across into the dial.
    classes = Counter()
    for interval, count in steps.items():
        size = abs(interval)
        name = ("repeat" if size == 0 else "step" if size <= 2
                else "skip" if size <= 4 else "leap")
        classes[name] += count
    return {
        "notes": len(top),
        "intervals": steps,
        "moves": total,
        "stepwise": classes["step"] / total if total else 0.0,
        "repeats": classes["repeat"] / total if total else 0.0,
        "skips": classes["skip"] / total if total else 0.0,
        "big_leaps": classes["leap"] / total if total else 0.0,
        "leaps": leaps,
        "leap_recovered": recovered / leaps if leaps else 0.0,
    }


def profile_distance(left: Counter, right: Counter) -> float:
    """Total variation distance between two interval histograms, 0 to 1."""
    left_total, right_total = sum(left.values()), sum(right.values())
    if not left_total or not right_total:
        return 1.0
    keys = set(left) | set(right)
    return 0.5 * sum(abs(left[k] / left_total - right[k] / right_total)
                     for k in keys)


def non_chord_tone_share(score: Score, analysis: Analysis) -> float | None:
    """How much of the top line is *not* in the chord the analyst named."""
    default_key = analysis.tonic_and_mode() or (score.tonic, score.mode)
    soprano = melody_part(score)
    if not soprano or not analysis.chords:
        return None
    placed = []
    for chord in analysis.chords:
        start = score.measure_beat(chord.measure, chord.beat)
        parsed = analyst_chord(chord, default_key)
        if start is not None and parsed is not None:
            placed.append((start, set(parsed.pitch_classes)))
    if not placed:
        return None
    placed.sort()
    outside = counted = 0
    for note in soprano:
        classes = None
        for start, pcs in placed:
            if start <= note.start + 1e-6:
                classes = pcs
            else:
                break
        if classes is None:
            continue
        counted += 1
        outside += note.pitch % 12 not in classes
    return outside / counted if counted else None


def bass_tone_shares(score: Score, analysis: Analysis) -> Counter | None:
    """Which note of the chord the real bass took, over the analyst's chords.

    This is the measurement behind `chances.bass_root`: how often tonal music
    actually puts the root in the bass, rather than the third or the fifth.
    """
    default_key = analysis.tonic_and_mode() or (score.tonic, score.mode)
    if not score.notes or not analysis.chords:
        return None
    placed = []
    for chord in analysis.chords:
        start = score.measure_beat(chord.measure, chord.beat)
        parsed = analyst_chord(chord, default_key)
        if start is not None and parsed is not None:
            placed.append((start, parsed))
    if not placed:
        return None
    placed.sort(key=lambda item: item[0])
    end_of_piece = max(n.end for n in score.notes)

    shares: Counter = Counter()
    for index, (start, chord) in enumerate(placed):
        finish = placed[index + 1][0] if index + 1 < len(placed) else end_of_piece
        sounding = [n for n in score.notes if n.start < finish and n.end > start]
        if not sounding:
            continue
        lowest = min(sounding, key=lambda n: n.pitch).pitch % 12
        interval = (lowest - chord.root) % 12
        if interval == 0:
            shares["root"] += 1
        elif interval in (3, 4):
            shares["third"] += 1
        elif interval in (6, 7, 8):
            shares["fifth"] += 1
        else:
            shares["other"] += 1
    return shares or None


# --------------------------------------------------------------------------
# Running it over a folder
# --------------------------------------------------------------------------

def analysis_files(directory: Path) -> list[Path]:
    """RomanText files written by a person.

    `analysis_automatic.rntxt` is a machine's reading, and measuring ourselves
    against another model's output would tell us how alike two guesses are,
    not whether either is right.
    """
    found = [p for p in directory.rglob("*.rntxt")]
    found += [p for p in directory.rglob("analysis.txt")]
    return sorted(p for p in found if "automatic" not in p.name.lower())


def pair_files(directory: Path) -> tuple[list[Path], dict[Path, Path]]:
    """Find scores, and match the analyses to them.

    Two conventions, because the corpora use two: an analysis sitting in the
    same folder as its score (When in Rome), and one naming its score in a
    catalogue header (the music21 chorale analyses, by BWV number).
    """
    scores = sorted(p for p in directory.rglob("*")
                    if p.suffix.lower() in SCORE_SUFFIXES)
    by_stem = {p.stem.lower(): p for p in scores}
    by_folder: dict[Path, list[Path]] = {}
    for score in scores:
        by_folder.setdefault(score.parent, []).append(score)

    analyses: dict[Path, Path] = {}
    for text in analysis_files(directory):
        beside = by_folder.get(text.parent)
        if beside:
            analyses.setdefault(beside[0], text)
            continue
        catalogue = (read_romantext(text).headers.get("BWV") or "").strip()
        if not catalogue:
            continue
        match = by_stem.get(f"bwv{catalogue}".lower()) or \
            by_stem.get(f"bwv{catalogue}.1".lower())
        if match is not None:
            analyses.setdefault(match, text)
    return scores, analyses


def run(directory, limit: int | None = None, style: str = "hymn",
        seed: int = 1) -> dict:
    """Measure the analyser against a folder of scores, and the generator
    against their melodies."""
    directory = Path(directory)
    scores, analyses = pair_files(directory)
    if limit:
        scores = scores[:limit]

    keys: list[KeyResult] = []
    harmony: list[HarmonyResult] = []
    real_intervals: Counter = Counter()
    real_profiles: list[dict] = []
    nct: list[float] = []
    bass_tones: Counter = Counter()
    unreadable_scores: list[str] = []
    without_melody = 0

    for path in scores:
        try:
            score = read_score(path)
        except Exception as error:                     # noqa: BLE001
            unreadable_scores.append(f"{path.relative_to(directory)}: {error}")
            continue
        if not score.notes:
            unreadable_scores.append(f"{path.relative_to(directory)}: no notes")
            continue

        name = str(path.relative_to(directory))
        analysis = read_romantext(analyses[path]) if path in analyses else None
        keys.append(measure_key(score, analysis, name))

        line = melody_part(score)
        if line:
            profile = melodic_profile(line)
            real_profiles.append(profile)
            real_intervals += profile["intervals"]
        else:
            without_melody += 1

        if analysis is not None:
            harmony.append(measure_harmony(score, analysis, name))
            share = non_chord_tone_share(score, analysis)
            if share is not None:
                nct.append(share)
            bass = bass_tone_shares(score, analysis)
            if bass is not None:
                bass_tones.update(bass)

    return {
        "directory": str(directory),
        "scores": len(scores),
        "unreadable": unreadable_scores,
        "keys": keys,
        "harmony": harmony,
        "real": _summarise_profiles(real_profiles, real_intervals),
        "without_melody": without_melody,
        "real_nct": sum(nct) / len(nct) if nct else None,
        "real_bass": dict(bass_tones),
        "generated": generated_profile(style, len(scores) or 20, seed),
    }


def melody_part(score: Score) -> list[Note]:
    """The one staff that carries a tune, or nothing.

    Better to measure no melody than to measure the top of a piano texture and
    call the result a melody.
    """
    for name, notes in score.parts.items():
        plain = name.lower().replace("\n", " ")
        if any(word in plain for word in MELODY_PART_NAMES) and notes:
            return notes
    return []


def _summarise_profiles(profiles: list[dict], intervals: Counter) -> dict:
    if not profiles:
        return {}
    moves = sum(p["moves"] for p in profiles)
    leaps = sum(p["leaps"] for p in profiles)
    def share(name: str) -> float:
        return (sum(p[name] * p["moves"] for p in profiles) / moves) if moves else 0.0

    return {
        "pieces": len(profiles),
        "notes": sum(p["notes"] for p in profiles),
        "intervals": intervals,
        "stepwise": share("stepwise"),
        "repeats": share("repeats"),
        "skips": share("skips"),
        "big_leaps": share("big_leaps"),
        "leap_recovered": (sum(p["leap_recovered"] * p["leaps"] for p in profiles)
                           / leaps if leaps else 0.0),
    }


def generated_profile(style: str, count: int, seed: int) -> dict:
    """The same measurements, taken of Middaw's own output."""
    from middaw.render import generate

    profiles, intervals = [], Counter()
    ornaments = 0
    melody_notes = 0
    for index in range(max(1, min(count, 60))):
        result = generate(f"a {style}", seed=seed + index)
        melody = [t for t in result.song.tracks if t.role == "melody"]
        notes = melody[0].notes if melody else []
        if not notes:
            continue
        profile = melodic_profile(notes)
        profiles.append(profile)
        intervals += profile["intervals"]
        melody_notes += len(notes)
        ornaments += sum(1 for e in (result.embellishments or [])
                         if getattr(e, "voice", "melody") == "melody")
    summary = _summarise_profiles(profiles, intervals)
    summary["style"] = style
    summary["ornament_share"] = ornaments / melody_notes if melody_notes else 0.0
    return summary


def format_report(report: dict) -> str:
    """The report as a human reads it: numbers first, excuses never."""
    lines: list[str] = []
    out = lines.append
    out(f"measured {report['scores']} score(s) in {report['directory']}")
    if report["unreadable"]:
        out(f"  {len(report['unreadable'])} could not be read:")
        for problem in report["unreadable"][:5]:
            out(f"    {problem}")

    keys = [k for k in report["keys"] if k.stated]
    signature_only = [k for k in report["keys"] if not k.stated]
    if keys:
        exact = sum(k.exact for k in keys)
        tonic = sum(k.tonic_right for k in keys)
        relative = sum(k.relative for k in keys)
        out("")
        out(f"key detection, against the {len(keys)} score(s) that state a key")
        out(f"  tonic and mode : {exact:4}/{len(keys)}  {exact / len(keys):6.1%}")
        out(f"  tonic only     : {tonic:4}/{len(keys)}  {tonic / len(keys):6.1%}")
        out(f"  relative error : {relative:4}/{len(keys)}  {relative / len(keys):6.1%}")
        wrong = [k for k in keys if not k.exact][:5]
        for k in wrong:
            out(f"    {_short(k.name)}: wrote {NOTE_NAMES[k.expected[0]]} {k.expected[1]}, "
                f"read {NOTE_NAMES[k.found[0]]} {k.found[1]} "
                f"(confidence {k.confidence:.2f})")

    if signature_only:
        inside = sum(k.in_collection for k in signature_only)
        out("")
        out(f"key detection, against {len(signature_only)} score(s) that give a "
            f"signature but never say major or minor")
        out(f"  tonic is in the written collection: {inside:4}/{len(signature_only)}"
            f"  {inside / len(signature_only):6.1%}")
        out("  (a signature names a collection, not a key, so that is the only "
            "question it can answer)")

    harmony = report["harmony"]
    if harmony:
        compared = sum(h.compared for h in harmony)
        root = sum(h.root_right for h in harmony)
        quality = sum(h.quality_right for h in harmony)
        unreadable = sum(h.unreadable for h in harmony)
        unnamed = sum(h.unnamed for h in harmony)
        out("")
        out(f"harmonic analysis, against {len(harmony)} human analyses "
            f"({compared} chords, on the analyst's own segmentation)")
        out(f"  same root      : {root:4}/{compared}  "
            f"{root / compared if compared else 0:6.1%}")
        out(f"  root + quality : {quality:4}/{compared}  "
            f"{quality / compared if compared else 0:6.1%}")
        out(f"  numerals our theory cannot express: {unreadable}")
        out(f"  spans we would not name           : {unnamed}")
        moved = [h for h in harmony if h.transposed]
        if moved:
            out(f"  scores in a different key from their analysis: "
                f"{len(moved)} ({', '.join(f'{_short(h.name)} {h.transposed:+d}' for h in moved)})")
        worst = sorted((h for h in harmony if h.compared), key=lambda h: h.accuracy)[:3]
        out("  hardest pieces: "
            + ", ".join(f"{_short(h.name)} {h.accuracy:.0%}" for h in worst))
        shown = [d for h in harmony for d in h.disagreements][:6]
        for wrote, read in shown:
            out(f"    analyst {wrote:16} we read {read}")

    real, made = report["real"], report["generated"]
    if real and made:
        out("")
        out(f"melody, real music vs Middaw's own ({made['style']})")
        if report.get("without_melody"):
            out(f"  {report['without_melody']} score(s) have no part that is a "
                f"single melodic line, and are left out of this comparison")
        out(f"{'':17}{'real':>10}{'middaw':>10}")
        out(f"  pieces         {real['pieces']:>10}{made['pieces']:>10}")
        out("  the four move classes, as middaw/chance.py rolls them")
        out(f"    repeat       {real['repeats']:>10.1%}{made['repeats']:>10.1%}")
        out(f"    step         {real['stepwise']:>10.1%}{made['stepwise']:>10.1%}")
        out(f"    skip         {real['skips']:>10.1%}{made['skips']:>10.1%}")
        out(f"    leap         {real['big_leaps']:>10.1%}{made['big_leaps']:>10.1%}")
        out(f"  leap turns back{real['leap_recovered']:>10.1%}"
            f"{made['leap_recovered']:>10.1%}")
        distance = profile_distance(real["intervals"], made["intervals"])
        out(f"  interval distribution distance: {distance:.3f} "
            f"(0 = identical, 1 = no overlap)")
        out("  most common intervals, in semitones")
        out(f"    real  : {_top_intervals(real['intervals'])}")
        out(f"    middaw: {_top_intervals(made['intervals'])}")
    bass = report.get("real_bass") or {}
    if bass:
        total = sum(bass.values())
        out("")
        out(f"the bass, over {total} analysed chords")
        for name in ("root", "third", "fifth", "other"):
            if bass.get(name):
                out(f"  {name:<6} {bass[name] / total:6.1%}")
        out("  (this is what `chances.bass_root` is set from)")
    if report.get("real_nct") is not None:
        out(f"  notes outside the named chord: real {report['real_nct']:.1%}, "
            f"middaw {made.get('ornament_share', 0):.1%} decorated")
    return "\n".join(lines)


def _short(name: str, width: int = 44) -> str:
    """A path a reader can tell apart: every score in a corpus is score.mxl."""
    if len(name) <= width:
        return name
    return "..." + name[-(width - 3):]


def _top_intervals(intervals: Counter, count: int = 6) -> str:
    total = sum(intervals.values()) or 1
    return "  ".join(f"{k:+d}:{v / total:.0%}" for k, v in intervals.most_common(count))
