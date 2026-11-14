# PiPWindow for macOS

A lightweight, native macOS application built with **SwiftUI**, **AppKit**, and **ScreenCaptureKit** that lets you turn any application window into a floating **60 FPS Picture-in-Picture (PiP)** window with aspect-ratio lock and smooth resizing.

## Features

- **60 FPS Hardware-Accelerated Capture**: Uses `ScreenCaptureKit` (`SCStream`) + `AVSampleBufferDisplayLayer` for low-latency Retina window streaming.
- **Aspect-Ratio Lock & Live Resize**: Automatically locks the floating PiP panel to the target window's aspect ratio and dynamically adjusts if the source window changes size.
- **Always-on-Top Floating Panel**: Stays above normal windows across Spaces and full-screen apps (`NSPanel` with `.floating` and `.canJoinAllSpaces`).
- **Hover HUD Controls**:
  - **S / M / L** quick size presets (`320px`, `460px`, `680px` width)
  - **Aspect Ratio Lock / Unlock** toggle (re-snaps to exact window aspect ratio when locked)
  - **Show / Hide Cursor** toggle in the captured stream
  - **Bring Source Window to Front** button
- **Menu Bar Extra (`MenuBarExtra`)**: Quick-access status bar popover with live window thumbnails, instant search filtering, one-click PiP toggle, and active PiP session badge.
- **Live Window Picker**: Previews open windows with parallel-captured high-DPI thumbnails, dimensions, search filter, and active PiP status indicators.

## Build & Run

### Option 1: Build `.app` Bundle (Recommended)

```sh
chmod +x build_app.sh
./build_app.sh
open PiPWindow.app
```

### Option 2: Open in Xcode or SwiftPM

```sh
open Package.swift
# or run directly:
swift run
```

> **Note:** On first launch, macOS will ask for **Screen Recording** permission (`System Settings → Privacy & Security → Screen & System Audio Recording`) so `ScreenCaptureKit` can list and stream application windows.
