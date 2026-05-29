# Pane

A minimal macOS window-snapping utility. Lives in the menu bar, no Dock icon.

## Two ways to snap

1. **Drag-to-top overlay (Windows 11 style)** — grab any window by its title bar and drag toward the top of the screen. A floating 3×3 layout picker fades in. Release over a cell to snap.
2. **Keyboard shortcuts** — modifier is `⌃⌥` (Control+Option):

   | Shortcut | Action       |
   |----------|--------------|
   | `⌃⌥←`   | Left half     |
   | `⌃⌥→`   | Right half    |
   | `⌃⌥↑`   | Maximize      |
   | `⌃⌥O`   | Top half      |
   | `⌃⌥L`   | Bottom half   |
   | `⌃⌥U`   | Top-left      |
   | `⌃⌥I`   | Top-right     |
   | `⌃⌥J`   | Bottom-left   |
   | `⌃⌥K`   | Bottom-right  |

## Build & run

```bash
./build.sh
open .build/release/Pane.app
```

On first launch macOS will prompt for **Accessibility** permission. Grant it in *System Settings → Privacy & Security → Accessibility*, then relaunch.

The build script ad-hoc codesigns the bundle so the Accessibility grant survives rebuilds.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+ / Swift 5.9+ toolchain

## Project layout

```
Sources/Pane/
  main.swift             – entry point
  AppDelegate.swift      – status item, permission flow, menu
  WindowManager.swift    – AXUIElement read/write
  ScreenCoords.swift     – AppKit ↔ AX coordinate helpers
  SnapZone.swift         – 9 snap targets + frame math
  DragMonitor.swift      – global mouse observer, drag detection
  SnapOverlay.swift      – floating panel + SwiftUI layout picker
  HotkeyManager.swift    – Carbon RegisterEventHotKey bindings
```
