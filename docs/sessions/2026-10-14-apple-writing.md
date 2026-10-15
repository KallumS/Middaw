# 2026-10-14 — the page's words follow Apple's writing guidelines

Part of a sweep of every repository, asked for by the user: the text people
see follows Apple's Human Interface Guidelines on writing, with the rules
Noterator wrote down in its decision 0053.

## What changed

- Buttons title-style: "Another take" → "Another Take", "Download .mid" →
  "Download MIDI File"; the seed's label "seed" → "Seed".
- The placeholder starts with a capital ("A sad lo-fi piano loop…"); the
  example prompts under it stay lowercase, because they are what gets typed.
- "Composing..." → "Composing…"; the summary line's "..." after a long
  progression → "…" (the CLI prints the same line).
- The chord chips' badge "repeats every 4 bars" → "Repeats every 4 bars".
- The fallback-tone note no longer says "vendor": "The piano sound couldn’t
  be loaded, so this is the built-in tone. To hear a piano, run
  tools/fetch_soundfont.py once."
- "Could not start audio: <browser text>" → "The sound couldn’t start. Click
  Play to try again." (the browser's own text goes to the console).
- The corpus note no longer says "priors": "no corpus loaded yet, so
  built-in musical rules are used".
- Errors that reach the page are sentences with a way forward. The server's
  were "bad content length", "body must be JSON", "prompt too large/long",
  "generation failed"; they are now "The request couldn’t be read. Reload the
  page and try again.", "That description is too long. Keep it under 2,000
  characters." and "Middaw couldn’t compose that. Try wording it
  differently, or report it as a bug." The page tells a server error from no
  answer at all: a dead server used to show the browser's "Failed to fetch",
  and now says "Middaw’s server can’t be reached. Check that it’s still
  running, then try again."

## Checked

- `python3 -m unittest discover -s tests -t .`: 234 tests, OK.
- Before and after screenshots of the page in headless Chromium; the longer
  button labels fit on one row.
- The three error paths driven in the browser (a 500 from the server, no
  answer, an answer that is not JSON) each show their new sentence.

## Left alone

- "What do you want to create?" is the prompt's label, a question to the
  user, so it stays in sentence case.
- The summary line (`lofi, sad | F Minor (Natural) | 82 BPM …`) is the
  parser's reading, data rather than prose.
- CLI help and output (`not understood:`, `wrote …`) keep the command line's
  lowercase convention.
