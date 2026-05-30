# Pane

<img src="Resources/icon.png" width="128" align="right" alt="Pane app icon">

A minimal macOS window-snapping utility. Lives in the menu bar, no Dock icon.

<p align="center">
  <video src="https://github.com/user-attachments/assets/6bcb637c-756d-4839-95ab-87b3d9ddfea3" width="720" controls muted></video>
</p>

## Install

1. Download the latest **[Pane.dmg](https://github.com/hayatayubi/pane/releases/latest)**.
2. Open the DMG and drag `Pane` into the `Applications` folder.
3. Double-click `Pane` in Applications. macOS will block it — click **OK**.
4. Open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway**.
5. Grant **Accessibility** when macOS prompts.

Pane now lives in your menu bar.

## How to use

**Drag any window's title bar toward an edge or corner.** The target zone outlines on screen; release to snap.

**Or use a keyboard shortcut** (customizable in Settings):

| Shortcut | Action       |
|----------|--------------|
| `⌃⌥↑`   | Maximize     |
| `⌃⌥←`   | Left half    |
| `⌃⌥→`   | Right half   |
| `⌃⌥O`   | Top half     |
| `⌃⌥L`   | Bottom half  |
| `⌃⌥U`   | Top-left     |
| `⌃⌥I`   | Top-right    |
| `⌃⌥J`   | Bottom-left  |
| `⌃⌥K`   | Bottom-right |

Click the menu bar icon → **Settings…** (or press `⌘,`) to rebind shortcuts, change the snap-outline color, or enable start-at-login.

<p align="center">
  <img src="Resources/screenshots/settings.png" width="540" alt="Pane settings window">
</p>

## Build from source

Requires macOS 14+ and the Xcode command-line tools.

```bash
./build.sh              # local build → .build/release/Pane.app
./build.sh --release    # universal release DMG → dist/Pane-<version>.dmg
```
