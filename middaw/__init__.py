"""Middaw - MIDI-first music generation from text prompts."""

__version__ = "0.1.0"

from middaw.spec import MusicSpec
from middaw.prompt import parse_prompt
from middaw.render import render

__all__ = ["MusicSpec", "parse_prompt", "render", "__version__"]
