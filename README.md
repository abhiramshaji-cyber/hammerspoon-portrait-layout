# Portrait window layout (Hammerspoon)

One hotkey restores a two-monitor portrait layout:

- Secondary portrait display: Chrome, Spotify, Slack stacked as exact vertical thirds.
- Primary (menu bar) display: Ghostty filling the whole screen.

Hotkey: `control` + `option` + `command` + `L`

Hammerspoon's `"alt"` and `"option"` are the same modifier. The config says `option`
because that is what the key is labelled on an Apple keyboard.

## Install

```sh
brew install --cask hammerspoon
git clone git@github.com:abhiramshaji-cyber/hammerspoon-portrait-layout.git ~/.hammerspoon
open -a Hammerspoon
```

Then grant Hammerspoon access under System Settings > Privacy & Security > Accessibility.
Without it, window frames silently do nothing, so the hotkey shows an alert instead.

Start at login, so the hotkey works from boot:

```sh
hs -c 'hs.autoLaunch(true)'
```

A Homebrew cask install does not register a login item on its own. Verify with
`hs -c 'return hs.autoLaunch()'`, or under System Settings > General > Login Items.

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
- Native fullscreen is deliberately not used. A natively fullscreen window gets its own Space
  and disappears whenever that Space is not the one on screen, and no hotkey can pull a Space
  forward. Ghostty is filled to the screen frame in the normal Space instead, so it is always
  visible. If it is found in native fullscreen it is taken out first, with a retry cap so a
  refused transition cannot loop.
- macOS keeps the focused app's windows above raised ones, so an unlisted app you were using
  would sit on top of the freshly placed layout. If the frontmost app is not part of the
  layout, focus moves into the layout. If you are already in a layout app, focus is left alone.
- The config pathwatcher is stored in a global. An unretained watcher is garbage collected and
  silently stops, which makes edits appear to have no effect.
- A missing app or a single connected display is reported in an alert rather than crashing
  or half applying the layout.

## Verified

Driven on a two by 1440x2560 portrait setup:

- Windows piled on top of each other, restored to exact contiguous thirds (30+843, 873+844, 1717+843 = 2560).
- Spotify minimized, then restored into its slot.
- Ghostty stuck in native fullscreen on its own Space, brought back to the shared Space and
  filled to the screen, confirmed via `hs.spaces.windowSpaces`.
- An unlisted focused app (Delivery) parked over the stack: left where it was, dropped below
  all three stack windows in z-order.
- Editing this file auto-reloads, confirmed by watching a global marker get cleared.
