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

