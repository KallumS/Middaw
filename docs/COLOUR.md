# The colour scheme

The house scheme, the same as Good Idea, Starting Blocks, Midi Suggester,
Midi Variator, Midi Catalogue and ScaleView: a dark cool-grey ground, a light
grey for the controls raised off it, dark ink on every control, and one
yellow for whatever is on. The tokens are in `:root` in `web/style.css`;
`tests/test_style.py` measures them.

## The four that carry it

| | value | what it is |
| --- | --- | --- |
| Accent | `#FFF200` | whatever is on: a chosen tab, a playing transport, the chosen clip, chosen notes, a primary action |
| Controls | `#A9AFBA` | buttons, slider grabs, notes that are not chosen |
| Ground | `#23272E` | the window |
| Ink | `#14171C` | the text on every button, whatever its fill |

## The rest

| token | value | where |
| --- | --- | --- |
| `--accent-hover`, `--accent-held` | `#FFF42E`, `#D1C600` | an accent button under the pointer, pressed |
| `--control-hover`, `--control-held` | `#C0C6CF`, `#8F96A2` | a grey button under the pointer, pressed |
| `--raised` | `#2A2F37` | menus, sheets, device panels, the chords lane: lighter than the window, as Apple's raised dark surfaces are |
| `--sunken` | `#1A1D23` | text fields, meters, the controller lane |
| `--roll` | `#111419` | the arrange timeline and the piano roll |
| `--beat` | `#1E2228` | beat lines and the out-of-key rows |
| `--rule` | `#3A404A` | dividers, bar lines, the edge of a menu |
| `--edge` | `#6D7581` | the edge of a field and of the instrument's range (3:1 or more) |
| `--text` | `#DDE1E7` | body text |
| `--text-dim` | `#B6BCC6` | secondary text |
| `--label` | `#BFC5CE` | a control's name beside it |
| `--warn` | `#D2483F` | a mark only: the edge of a warning, a clipping meter, a note outside the instrument. **Never words** |
| `--warn-text` | `#FFA6A0` | the words of a warning |
| `--playhead`, `--focus` | `#F2F4F7` | the playhead and the keyboard ring: near-white, never the accent, so focus is not mistaken for "on" |

Two values differ from the house file: `--text-dim` and `--warn-text` are a
step brighter than Good Idea's `#B0B6C0` and `#FF9E96`, because Middaw puts
secondary text and warnings on raised panels too, where those measure 6.6:1
and 6.8:1. Every word here is 7:1 on every surface it can sit on.

## Rules

- **Every grey is cool**: R < G < B. A neutral or warm grey looks dirty
  beside the accent.
- **On is the accent and a dark bar** under the label, so a chosen state never
  rests on colour alone.
- **The tune takes the accent** in a preview (Good Idea 0009); chords and bass
  take the controls' grey.
- **Under Increase Contrast** (`prefers-contrast: more`) the dim text, labels,
  rules and edges brighten.
