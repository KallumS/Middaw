# Review against Apple's Human Interface Guidelines: Foundations

The same review the family's windows had (Good Idea's `docs/apple-hig-review.md`),
for Middaw's native app. Being native, most of what the family's ReaImGui
windows could not do comes with the platform: VoiceOver reads the controls,
the system's text size, contrast and motion settings apply, documents, undo
and menus are the Mac's own.

## Met, and how

| Guideline | Here |
| --- | --- |
| **Text 7:1, controls 3:1** | Every word is 7:1 on every surface; marks you follow or grab (playhead, edges, notes) are 3:1 or more. `PaletteTests` measures `HousePalette` on every build |
| **28 pt controls, 12 pt apart** | `HouseButtonStyle` is 28 points tall; panels space bezelled controls 12 apart |
| **Not colour alone** | On = the accent *and* a dark bar under the label; playing turns ▶ into ■; warnings are worded; the chosen clip has a frame as well as a colour |
| **Nothing important at the bottom** | The status line is at the top of the window, under the toolbar |
| **Nothing times out** | A message stays until Dismiss or a newer one; the Battle Pass waits for an empty status line and marks its ring instead |
| **Mistakes are cheap** | Every change is one undo step on the window's UndoManager, named in Edit > Undo; documents autosave and keep versions; a generated result is heard before it is used |
| **The Mac's own patterns** | Documents and windows, the menu bar with its shortcuts, toolbar, popovers, segmented controls, split views, context menus, Open and Save panels |
| **System shortcuts left alone** | Cmd+N, Cmd+T, Cmd+W, Cmd+Q are the system's; Middaw's own use Option-Cmd (New Track is ⌥⌘N, as in Logic) or plain keys when no text field has focus |
| **Keyboard alone** | Every control is a real SwiftUI control, reached by Full Keyboard Access; Space plays, Esc lets go of the selection |
| **Sound never starts by itself** | Only Play, Hear and a key you press make sound |
| **Concise words** | Labels are a word or two; explanations are tooltips (`.help`) |
| **Dark only** | Allowed for media-focused apps, and the house scheme |

## Not met

- **VoiceOver inside the drawn views.** The arrange view, piano roll and
  score are drawn, so VoiceOver reads each as one element. Every action on
  them is also a menu item or a key, but the notes cannot be read out yet.
- **Dynamic Type** does not reach the drawn views' labels.
- **Right to left.** English only; time runs left to right, as in every DAW.

## Not tried

The app was built and tested by CI only. It has not yet been looked at on a
real display, with VoiceOver, or under Increase Contrast and Reduce Motion.
