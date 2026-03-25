# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Yoink is a native macOS daemon that provides a keyboard-driven window picker for AeroSpace (tiling window manager). It lets you pull ("yoink") windows from other workspaces into your current one. Built with Swift/AppKit, no external dependencies.

**Requirements:** Swift 6.2+, macOS 26+ (Tahoe) — the UI uses `NSGlassEffectView` which requires macOS 26.

## Build & Run

```bash
swift build                    # Debug build
swift build -c release         # Release build

# Run as daemon (stays resident, listens for SIGUSR1)
swift build -c release && .build/release/yoink --daemon

# Trigger picker (sends SIGUSR1 to running daemon)
.build/release/yoink
```

No tests, linter, or formatter are configured.

## Architecture

**Daemon IPC pattern:** `main.swift` writes PID to `/tmp/yoink.pid`. First launch with `--daemon` starts the resident process. Subsequent launches detect the PID file and send SIGUSR1 to toggle the picker panel.

**Data flow:** `main.swift` → `YoinkController` (manages panel lifecycle, keyboard input, search filtering) → `Aerospace` (shells out to `aerospace` CLI to list workspaces/windows, move windows) → `AeroWindow` (data model).

**UI layer:** `Views.swift` defines `YoinkPanel` (NSPanel subclass with glass effect), `WindowCell` (renders app icon, name, title, workspace badge), and `WindowRowView` (custom selection highlight). `Layout.swift` centralizes all design constants as a nested enum.

**Performance:** Window data is fetched via parallel `aerospace` CLI calls using DispatchGroup. App icons are cached from NSWorkspace.
