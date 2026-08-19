# Portrait window layout (Hammerspoon)

One hotkey restores a two-monitor portrait layout:

- Secondary portrait display: Chrome, Spotify, Slack stacked as exact vertical thirds.
- Primary (menu bar) display: Ghostty filling the whole screen.

Any app that is closed gets launched, and any app sitting in native fullscreen gets pulled
out of it, so one press lands the layout from any starting state.

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
  `allWindows()` and unminimized before placement. A hidden app (`cmd`+`H`) is unhidden, since
  its windows resize fine but invisibly.
- Only standard windows are accepted. A launching app can briefly expose a splash screen or a
  panel as its `mainWindow()`, and placing that instead leaves the real window unmoved.
- `setFrame` gets dropped mid-animation, right after unminimize, or while an app is still
  finishing its launch, so each placement is verified and retried with a pause between tries.
- A closed app is launched and then waited on until it actually has a window, up to 20s. The
  wait costs nothing when the app is already open.
- **Any** app in native fullscreen is taken out of it first, not just Ghostty. A fullscreen
  window refuses to be resized, so without this the app was silently skipped. The exit
  animation is waited out before placement, because `setFrame` during it does not stick.
- Native fullscreen is never re-applied. A natively fullscreen window gets its own Space and
  disappears whenever that Space is not the one on screen, and no hotkey can pull a Space
  forward. Ghostty is filled to the screen frame in the normal Space instead, so it is always
  visible.
- The layout pass runs in a coroutine and yields to a timer whenever it waits. Hammerspoon is
  single threaded, so blocking would freeze the very launches and animations being waited on.
  One pass runs at a time; a press during a pending launch is ignored rather than interleaved.
- macOS keeps the focused app's windows above raised ones, so an unlisted app you were using
  would sit on top of the freshly placed layout. If the frontmost app is not part of the
  layout, focus moves into the layout. If you are already in a layout app, focus is left alone.
- The config pathwatcher is stored in a global. An unretained watcher is garbage collected and
  silently stops, which makes edits appear to have no effect.
- An app that cannot be found, never opens a window, refuses to leave fullscreen, or will not
  resize is named in a `Skipped:` alert with the reason, rather than crashing or failing
  silently. A single connected display is reported the same way.

## Verified

Driven on a two by 1440x2560 portrait setup:

- Windows piled on top of each other, restored to exact contiguous thirds (30+843, 873+844, 1717+843 = 2560).
- Spotify minimized, then restored into its slot.
- Slack in native fullscreen: left fullscreen and landed in the bottom third.
- Spotify and Slack both quit: both launched cold and placed in their slots.
- Ghostty in native fullscreen *and* Spotify quit in the same press: all four correct.
- Ghostty stuck in native fullscreen on its own Space, brought back to the shared Space and
  filled to the screen, confirmed via `hs.spaces.windowSpaces`.
- Hotkey pressed three times during a cold Slack launch: the extra presses were dropped, Slack
  still placed, no errors in the Hammerspoon console, and the next press worked normally.
- An unlisted focused app (Delivery) parked over the stack: left where it was, dropped below
  all three stack windows in z-order.
- Editing this file auto-reloads, confirmed by watching a global marker get cleared.

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Licence

MIT. See [LICENSE](LICENSE).
