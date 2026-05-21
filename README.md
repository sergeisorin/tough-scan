# Tough Scan

Tough Scan is a native iPhone app for progressively scanning hard-to-read printed documents under poor conditions. It stays fully local on the device, reconstructs the scanned document over time, extracts Hebrew and English text, and shows confidence overlays for areas that are successful, uncertain, very uncertain, or still need scanning.

## Current Status

This repository is in MVP scaffolding. The first implementation focuses on:

- Pure Swift scan-domain logic with tests.
- Native iOS app structure.
- AVFoundation/Vision-ready service boundaries.
- Calm, clinical review and rescan UI.

## Context

- [Requirements](REQUIREMENTS.md)
- [Architecture](ARCHITECTURE.md)
- [Memory](MEMORY.md)

## Development

The core scan logic is available as a Swift package so it can be checked without launching the iOS app:

```bash
swift run ToughScanCoreChecks
```

The iOS app scaffold is described by `project.yml` for XcodeGen.

```bash
brew install xcodegen
xcodegen generate
open ToughScan.xcodeproj
```

If XcodeGen is already installed, only the last two commands are needed.

## Manual iPhone Validation

Use a real iPhone for camera validation; the simulator cannot prove the live scan pipeline.

1. Run the app on iPhone 15 Pro.
2. Start a scan and point at printed English text.
3. Confirm the confidence grid updates without using the debug stronger-pass button.
4. Repeat with printed Hebrew text.
5. Try lower light or faded text and confirm weak regions remain marked for rescan.
6. Confirm no raw OCR text appears in debug logs.

