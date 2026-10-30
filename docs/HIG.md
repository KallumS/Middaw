# Review against Apple's Human Interface Guidelines: Foundations

The same review the family's windows had (Good Idea's `docs/apple-hig-review.md`),
for Middaw's DAW. Middaw is a web page rather than a ReaImGui window, so some
things those scripts could not do, it can: the browser gives it real keyboard
focus, system contrast settings and a screen reader's view of the controls.

## Met, and how

| Guideline | Here |
| --- | --- |
| **Text 7:1, controls 3:1** | Every word is 7:1 on every surface; marks you follow or grab (focus, playhead, edges, notes) are 3:1 or more. Measured by `tests/test_style.py` |
| **13 pt type, 28 pt controls, 12 pt apart** | `--control-h` and `--gap` at a 13 px root; measured by the same test |
| **Text can grow to 200%** | View → Text Size, or Cmd+= / Cmd+- / Cmd+0. Everything is in rem, so controls, rows and canvases grow with it; the toolbar wraps rather than running off the edge |
| **Not colour alone** | On = the accent *and* a dark bar under the label; playing turns ▶ into ■; warnings are worded; the chosen clip has a frame as well as a colour |
| **Nothing important at the bottom** | The status line is at the top, under the toolbar |
| **Nothing times out** | A message stays until Dismiss or a newer one; the Battle Pass waits for an empty status line rather than replacing yours, and marks its button instead |
| **Mistakes are cheap** | Every change is one undo step, named in the Edit menu; large ones offer Undo in the status line; a generated result is heard before it is used |
| **Keyboard alone** | Every control is a real button, select or field, reached by Tab, with a near-white ring. Space plays (not when a button has focus - then it presses the button), Esc lets go of a menu, a sheet, a field, then the selection, in that order |
| **System shortcuts left alone** | Only the shortcuts every DAW uses; Cmd+Q, Cmd+W, Cmd+H and the like are the browser's |
| **Raised surfaces lighter** | Menus, sheets and device panels are `--raised`, lighter than the window |
| **Dark only** | Allowed for media-focused apps, and the house scheme |
| **Increase Contrast** | `prefers-contrast: more` brightens dim text, labels, rules and edges |
| **Reduce Motion** | Nothing animates but the playhead, which follows the music |
| **Sound never starts by itself** | Only Play, Audition, Hear and a key you press make sound, and each shows a Stop |
| **Familiar patterns** | Menus with their shortcuts written beside them, an ellipsis on everything that asks for more, segmented controls for one-of-several, disclosure triangles for the rarely used |
| **Concise words** | Labels are a word or two; explanations live in tooltips, not on the screen. The few lines of secondary text say something about *this* thing (an instrument's range, where a clip came from), never how to use a control |
| **Privacy** | Nothing leaves the machine. The song autosaves in the browser; the Battle Pass in `data/user/` |

## Not met

- **Screen reader names for the canvases.** The arrange view, piano roll and
  score are drawn, so VoiceOver reads them as one image each. Every action on
  them is also a menu item or a key, but the notes themselves cannot be read
  out yet.
- **Right to left.** English only; time runs left to right, as in every DAW.

## Not tried

- On real displays, under bright and dim light, and on Windows and Linux.
- With VoiceOver, Voice Control and Full Keyboard Access in a real browser.
