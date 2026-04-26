# Mirra

A lightweight macOS menu bar app that shows a floating camera preview. Quick check before calls, always-on-top for presentations.

## Features

- **Floating preview** -- always-on-top camera window you can drag anywhere
- **Multiple shapes** -- circle, square, or rectangle (4:3)
- **Configurable border radius** -- none, small, medium, large, extra large
- **Size presets** -- small, medium, large, extra large
- **Corner placement** -- snap to any corner, center, or drag freely
- **Multi-monitor** -- choose which display to show the preview on
- **Mirror toggle** -- flip the camera horizontally
- **Hover behavior** -- fade to a custom opacity or hide entirely when you mouse over
- **Keyboard shortcuts** -- control everything without opening the menu
- **Launch at login** -- start automatically with macOS

## Keyboard Shortcuts

All shortcuts use `Cmd+Shift`:

| Shortcut | Action |
|----------|--------|
| `⇧⌘M` | Toggle preview on/off |
| `⇧⌘C` | Cycle cameras |
| `⇧⌘F` | Toggle mirror |
| `⇧⌘S` | Cycle size |
| `⇧⌘P` | Cycle placement |
| `⇧⌘H` | Cycle shape |

## Requirements

- macOS 14+
- Camera access permission

## Building

Open `Mirra.xcodeproj` in Xcode and build the Mirra scheme. No external dependencies.
