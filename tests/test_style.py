"""The house scheme, measured: every word 7:1, every button's ink 7:1 on its
fill, greys cool, controls 28 points, red never used for words."""

import re
import unittest
from pathlib import Path

WEB = Path(__file__).resolve().parent.parent / "web"
CSS = (WEB / "style.css").read_text()


def tokens():
    root = CSS[CSS.index(":root {"):]
    root = root[:root.index("}")]
    return {m[0]: m[1] for m in re.findall(r"--([\w-]+):\s*(#[0-9A-Fa-f]{6})", root)}


def luminance(hex_colour):
    def channel(c):
        c = int(c, 16) / 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (channel(hex_colour[i:i + 2]) for i in (1, 3, 5))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


class TestHouseScheme(unittest.TestCase):
    T = tokens()

    def test_every_word_is_seven_to_one_on_every_surface(self):
        for word in ("text", "text-dim", "label", "warn-text"):
            for ground in ("ground", "raised", "sunken", "roll"):
                with self.subTest(word=word, ground=ground):
                    self.assertGreaterEqual(contrast(self.T[word], self.T[ground]), 7.0)

    def test_ink_is_seven_to_one_on_every_button_fill(self):
        for fill in ("control", "control-hover", "accent", "accent-hover"):
            with self.subTest(fill=fill):
                self.assertGreaterEqual(contrast(self.T["ink"], self.T[fill]), 7.0)
        # pressed, for the moment the button is held: still readable
        self.assertGreaterEqual(contrast(self.T["ink"], self.T["control-held"]), 4.5)

    def test_things_you_grab_or_follow_are_three_to_one(self):
        for mark in ("focus", "playhead", "edge", "note", "control", "accent"):
            with self.subTest(mark=mark):
                self.assertGreaterEqual(contrast(self.T[mark], self.T["roll"]), 3.0)

    def test_greys_are_cool(self):
        for name, value in self.T.items():
            r, g, b = (int(value[i:i + 2], 16) for i in (1, 3, 5))
            if name.startswith(("accent", "warn")) or (r == g == b):
                continue
            with self.subTest(name=name):
                self.assertTrue(r <= g <= b and r < b, f"{name} {value}")

    def test_red_never_colours_words(self):
        sources = [CSS] + [p.read_text() for p in (WEB / "app").rglob("*.js")]
        for text in sources:
            self.assertNotRegex(text, r"(?<!-)color:\s*var\(--warn\)")
            self.assertNotIn("fillStyle = U.css('--warn'); g.fillText", text)

    def test_controls_are_twenty_eight_points_twelve_apart(self):
        root_px = float(re.search(r"font-size:\s*([\d.]+)px", CSS[CSS.index(":root {"):]).group(1))
        self.assertEqual(root_px, 13)
        height = float(re.search(r"--control-h:\s*([\d.]+)rem", CSS).group(1))
        gap = float(re.search(r"--gap:\s*([\d.]+)rem", CSS).group(1))
        self.assertAlmostEqual(height * root_px, 28, delta=0.1)
        self.assertAlmostEqual(gap * root_px, 12, delta=0.1)

    def test_a_chosen_button_is_marked_by_more_than_colour(self):
        self.assertRegex(CSS, r'button\[aria-pressed="true"\]::after[^{]*\{[^}]*background:\s*var\(--ink\)')

    def test_the_status_line_is_at_the_top(self):
        html = (WEB / "index.html").read_text()
        self.assertLess(html.index('id="status"'), html.index('id="workspace"'))


if __name__ == "__main__":
    unittest.main()
