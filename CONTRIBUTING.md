# Contributing

Issues and pull requests are welcome. This is a small project, so the bar is
simple: keep each change focused on one thing, and say why in the description.

## Getting set up

Clone into `~/.hammerspoon`, then open Hammerspoon and grant it Accessibility
access under System Settings > Privacy & Security > Accessibility. Without that,
window frames silently do nothing.

## Before opening a pull request

- Reload the config from the Hammerspoon menu bar icon, then press the hotkey
  with the apps closed. One press should land the whole layout from a cold start.
- Also test it with an app sitting in native fullscreen, since pulling apps out
  of fullscreen is the part that most often breaks.
- Say which macOS version and monitor arrangement you tested on.

The layout is currently hard coded to one two monitor arrangement. Making it
configurable is welcome, but please open an issue first so the shape of the
config can be agreed.

Issues labelled `good first issue` are self contained and a good place to start.
