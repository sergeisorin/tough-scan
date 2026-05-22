# Tough Scan

Tough Scan is a privacy-first iPhone app for recovering hard-to-read printed documents when a normal photo scan is not enough. It progressively rebuilds the page from live camera frames, extracts Hebrew and English text locally, and shows exactly which regions are reliable, uncertain, or still need another pass. Document images, recognized text, AI review notes, and exports stay on your iPhone unless you explicitly share them.

## The Problem

Important documents are often scanned in the worst conditions: faded ink, glare, low light, skewed paper, shaky hands, or text in more than one language. Standard scanning apps usually treat capture as a single moment. If that moment is bad, the user discovers the failure later as a blurry PDF or broken OCR text.

That is especially painful when the document is personal, difficult to replace, or contains sensitive information. Users need a recovery workflow that tells them what is good enough before they leave the scan, without sending private document content to a server.

## How Tough Scan Helps

Tough Scan treats scanning as an evidence-gathering process instead of a one-shot photo, with privacy built into the workflow. No private document information leaves the app.

- **Progressive capture:** the app evaluates camera frames continuously and keeps the strongest evidence for each document region.
- **Guided rescans:** confidence overlays highlight missing or weak areas so the user knows where to move next.
- **Local OCR:** Hebrew and English text recognition runs through Apple's on-device Vision APIs.
- **Review before export:** users can inspect the reconstructed page, recovered text, structured details, and weak regions before sharing anything.
- **Local exports:** the app prepares a multi-page PDF and text file on device.
- **AI-assisted extraction:** on supported devices, Apple Intelligence helps turn recovered text into structured details and cleaner copy while keeping notes local and advisory.

## AI-Assisted Text Extraction

After the scan recovers text, Tough Scan can use Apple Intelligence on supported devices to pull useful information out of noisy OCR:

- **Extract key details:** pull out names, dates, phone numbers, emails, addresses, amounts, and document type.
- **Suggest cleaned text:** improve OCR readability while preserving the original meaning and marking uncertain words.
- **Summarize when useful:** create a short orientation summary after the important text has been extracted.

AI output is treated as review support, not ground truth. You can inspect the original recovered text, rerun scan passes for weak regions, and choose whether to include Apple Intelligence suggestions in the exported text file.

## Install On Your iPhone

Tough Scan is an iOS project you can build and run directly from Xcode.

### Requirements

- A Mac with Xcode and the iOS 26 SDK.
- XcodeGen 2.42.0 or newer.
- An iPhone running iOS 26 or later.
- A free or paid Apple Developer account configured in Xcode for device signing.

### Run From Source

Clone the project, generate the Xcode project, then open it:

```bash
git clone <repository-url>
cd tough-scan
brew install xcodegen
xcodegen generate
open ToughScan.xcodeproj
```

In Xcode:

1. Select the `ToughScan` scheme.
2. Connect your iPhone.
3. Choose your iPhone as the run destination.
4. Set your development team under Signing & Capabilities if Xcode asks.
5. Press Run.

The first launch asks for camera access because Tough Scan uses the camera to recover document pages. Processing stays on the device.

## Using The App

1. Tap **Start local scan**.
2. Hold the full printed page in frame so all document edges are visible.
3. Follow the highlighted confidence regions while the app gathers stronger evidence.
4. Open Review when the page has enough information.
5. Copy recovered text, rescan weak areas, add another page, or export the local result.
6. Share the generated PDF and text file only when you choose to export.

## Privacy Model

Tough Scan is built for personal and sensitive documents:

- No account is required.
- No server OCR is used.
- No cloud sync is part of the app flow.
- OCR runs locally through Apple's Vision APIs.
- Apple Intelligence notes, when available, are local and optional.
- Exports are created locally and shared only through the iOS share sheet.

## What Is In This Repo

The repository contains the native app, scan-domain logic, and test coverage:

- `Sources/ToughScanCore/` - pure Swift scan-domain models, confidence maps, tile evidence, and progressive scan sessions.
- `Sources/ToughScanCoreChecks/` - executable checks for core behavior without launching the iOS app.
- `ToughScan/` - SwiftUI app, AVFoundation camera integration, Vision OCR, image processing, review UI, and export flow.
- `ToughScanTests/` - unit tests for processing, review, export, camera state, and Apple Intelligence availability behavior.
- `project.yml` - XcodeGen definition for the iOS project.
- `.github/workflows/ci.yml` - Swift package checks plus iOS build/test when an iOS 26 SDK is available.

## Product Principles

- **Local first:** document images, OCR text, exports, and intelligence notes stay on the device unless the user explicitly shares the export.
- **Confidence over mystery:** the app surfaces uncertainty by region and text line instead of pretending every scan succeeded.
- **Calm recovery flow:** the UI uses short, concrete guidance such as "Revisit the highlighted weak text region."
- **Language-aware scanning:** printed Hebrew and English are first-class scanning targets.
- **Reviewable output:** users can copy recovered text, add pages, rescan weak areas, or export only when the page has enough evidence.

## For Contributors

Run the core package checks without launching the iOS app:

```bash
swift run ToughScanCoreChecks
```

Build the Swift package:

```bash
swift build
```

Build the iOS app from the generated Xcode project:

```bash
xcodebuild -project ToughScan.xcodeproj -scheme ToughScan -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

CI runs the core Swift build and checks on every push and pull request. When the runner has an iOS 26 SDK, CI also generates the Xcode project, builds the app, and runs the iOS unit tests.

## Best For

Tough Scan is designed for printed personal documents, Hebrew and English text, multi-page recovery, and situations where privacy matters as much as readability.

