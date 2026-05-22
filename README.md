# Tough Scan

Tough Scan is a native iPhone app for progressively scanning hard-to-read printed documents under poor conditions. It stays fully local on the device, reconstructs the scanned document over time, extracts Hebrew and English text, and shows confidence overlays for areas that are successful, uncertain, very uncertain, or still need scanning.

## Current Status

This repository is in MVP scaffolding. The first implementation focuses on:

- Pure Swift scan-domain logic with tests.
- Native iOS app structure.
- AVFoundation/Vision-ready service boundaries.
- Calm, clinical review and rescan UI.

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
2. Start a scan and hold a full printed page in frame so all document edges are visible.
3. Confirm the app asks you to hold document edges in frame when only part of the page is visible.
4. Confirm the confidence grid updates from real camera frames after the document is detected and flattened.
5. Repeat with a skewed English page and confirm perspective normalization still allows OCR.
6. Repeat with printed Hebrew text.
7. Try lower light or faded text and confirm weak regions remain marked for rescan.
8. In review, tap Add another page and confirm the app returns to live scan with a fresh confidence grid.
9. Scan a second page, then export the local result.
10. Confirm the share sheet offers one PDF and one text file.
11. Confirm the PDF contains both pages and the text file separates OCR text by page.
12. Confirm no raw OCR text appears in debug logs.

## Apple Intelligence Validation

Use an Apple Intelligence-capable iPhone running iOS 26 or later. Keep all validation local on device and do not capture screenshots or logs containing OCR text, generated summaries, or extracted personal details.

1. With Apple Intelligence enabled and model assets ready, scan an English printed page and confirm Summarize, Extract key details, and Suggest cleaned text each produce advisory notes.
2. Repeat with printed Hebrew text and confirm unsupported-language copy appears if generation is unavailable for the current locale.
3. Turn Apple Intelligence off in Settings, reopen Review, and confirm action buttons are unavailable with clear fallback copy.
4. Validate the model-not-ready state on a device that is still downloading or preparing Apple Intelligence assets.
5. Start an Apple Intelligence action, add or remove a page before it completes, and confirm stale results do not appear in the review panel or export.
6. Run one successful action and one failing or unavailable action; confirm successful notes remain visible and the failed action shows retry copy.
7. Export with “Include intelligence notes in export” off and confirm the text file contains only OCR or structured document text.
8. Export with “Include intelligence notes in export” on and confirm the text file includes the clearly labeled Apple Intelligence suggestions section.

