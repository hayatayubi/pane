# Pane

<img src="Resources/icon.png" width="128" align="right" alt="Pane app icon">

A small macOS menu bar app for snapping windows. Drag a window to the edge or corner of the screen and it fills that part of the display, or use a keyboard shortcut. There's no Dock icon.

<p align="center">
  <video src="https://github.com/user-attachments/assets/6bcb637c-756d-4839-95ab-87b3d9ddfea3" width="720" controls muted></video>
</p>

## Install

1. Download **[Pane.dmg](https://github.com/hayatayubi/pane/releases/latest)**.
2. Open it and drag Pane into Applications.
3. Open Pane. When macOS asks, give it Accessibility access (it needs this to move other apps' windows).

The app is signed and notarised, so it opens without any Gatekeeper warnings. Needs macOS 14 or later.

If you're updating from 0.1.4 or earlier, the bundle ID changed in 0.1.5, so macOS will ask for Accessibility access again.

## Using it

Drag a window by its title bar towards an edge or corner. An outline shows where it'll land. Let go to snap. If you change your mind, drag it back out within a few seconds and it returns to its old size.

You can also use the keyboard. These are the defaults, and you can change them in Settings:

| Shortcut | Action       |
|----------|--------------|
| `⌃⌥↑`    | Maximise     |
| `⌃⌥C`    | Centre       |
| `⌃⌥←`    | Left half    |
| `⌃⌥→`    | Right half   |
| `⌃⌥O`    | Top half     |
| `⌃⌥L`    | Bottom half  |
| `⌃⌥U`    | Top left     |
| `⌃⌥I`    | Top right    |
| `⌃⌥J`    | Bottom left  |
| `⌃⌥K`    | Bottom right |

Click the menu bar icon and choose **Settings** (or press `⌘,`) to rebind shortcuts, change the outline colour, set how close to an edge you need to drag, start Pane at login, or exclude apps you don't want it to touch.

<p align="center">
  <img src="Resources/screenshots/settings.png" width="540" alt="Pane settings window">
</p>

## Building from source

You need macOS 14+ and the Xcode command line tools.

```bash
./build.sh              # local build, output in .build/release/Pane.app
./build.sh --release    # universal DMG in dist/
```

A release build is ad-hoc signed unless you set `DEVELOPER_ID_APPLICATION` to a Developer ID identity, in which case it's signed with the hardened runtime and ready to notarise.

## Licence

MIT.
