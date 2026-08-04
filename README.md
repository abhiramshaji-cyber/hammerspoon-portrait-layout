# Portrait window layout (Hammerspoon)

One hotkey restores a two-monitor portrait layout:

- Secondary portrait display: Chrome, Spotify, Slack stacked as exact vertical thirds.
- Primary (menu bar) display: Ghostty in native fullscreen.

Hotkey: `ctrl` + `alt` + `cmd` + `L`

## Install

```sh
brew install --cask hammerspoon
git clone git@github.com:abhiramshaji-cyber/hammerspoon-portrait-layout.git ~/.hammerspoon
open -a Hammerspoon
```

Then grant Hammerspoon access under System Settings > Privacy & Security > Accessibility.
Without it, window frames silently do nothing, so the hotkey shows an alert instead.

## Configuration

Everything tunable is in the first five lines of `init.lua`:

| Setting | Meaning |
| --- | --- |
| `HOTKEY` | Modifier list and key. |
| `STACK` | Apps top to bottom. The stack splits evenly by list length, so a fourth app gives quarters. |
| `FULLSCREEN_APP` | App that gets the other display in native fullscreen. |
| `STACK_ON` | `"secondary"` or `"primary"`. Which display holds the stack. Flip this if the stack lands on the wrong panel. |

Saving the file auto-reloads the config, so no restart is needed.

## Why it is written this way

Nothing is hardcoded in pixels. Screen frames are read on every keypress, so rotating a
display, changing resolution, or unplugging a monitor needs no config change.

Specific cases it handles:

- Slot boundaries are integers shared between neighbours, so there is no 1px gap or overlap
  when the screen height does not divide evenly (2530 / 3).
- A minimized app reports no `mainWindow()`, so windows are also looked up through
  `allWindows()` and unminimized before placement.
- `setFrame` gets dropped mid-animation or right after unminimize, so each placement is
  verified and retried.
- Native fullscreen ignores `setFrame` and follows the window's own screen. If the fullscreen
  app is on the wrong display it is taken out of fullscreen, moved, then put back, with a
  retry cap so a refused transition cannot loop.
- A missing app or a single connected display is reported in an alert rather than crashing
  or half applying the layout.

## Verified

Driven on a two by 1440x2560 portrait setup:

- Windows piled on top of each other, restored to exact contiguous thirds (30+843, 873+844, 1717+843 = 2560).
- Spotify minimized, then restored into its slot.
- Ghostty fullscreen on the wrong display, then returned to fullscreen on the right one.
- Ghostty already correct: left alone, its Space untouched.
