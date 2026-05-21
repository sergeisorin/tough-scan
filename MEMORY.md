# Tough Scan Memory

## User Decisions

- Build a native iPhone app.
- Use Swift and native Apple frameworks instead of React Native or Flutter.
- Target the user's iPhone 15 Pro first.
- Keep the app fully local with no server.
- Use a custom progressive scanning pipeline, not VisionKit's single-shot document scanner.
- Support printed Hebrew and English in the MVP.
- Produce both reconstructed document output and extracted OCR text.
- Show combined confidence: region-level scanning guidance plus word/line-level review highlights.
- Use a hybrid scan experience: continuous accumulation while scanning, then guided rescans for weak regions.
- Design tone: calm, clinical, precise.
- Use Impeccable guidance for UI and UX work.
- Use superpowers workflows for development.

## Product Principles

- Recovery over capture: the app helps users recover difficult text, not merely take a document photo.
- Local by default: the user should trust that sensitive document content stays on the iPhone.
- Evidence-based UI: confidence states must reflect real scan/OCR evidence and avoid false certainty.
- Progressive guidance: the app should always make the next best action clear.
- Accessibility: confidence must be understandable without relying only on color.

## Technical Principles

- Put scan logic in pure Swift modules that can be tested without camera hardware.
- Keep AVFoundation, Vision, Core Image, and SwiftUI behind narrow boundaries.
- Prefer deterministic local processing first, with a hook for future local Core ML enhancement.
- Avoid logging OCR text or raw document content.
- Use TDD for domain behavior and confidence scoring.

## Open Decisions

- Exact iOS deployment target after checking Xcode and Vision language availability.
- Exact OCR language identifiers to use for Hebrew and English on the target iOS SDK.
- Whether to add a simple single-shot debug mode later for quality comparison.
- Final export format details: PDF metadata, confidence annotations, and text sidecar format.

## Build Notes

- The local command-line Swift toolchain did not expose `XCTest` or `Testing`, so core behavior checks currently run through `swift run ToughScanCoreChecks`.
- XcodeGen was not installed during initial scaffolding. `project.yml` is ready for `xcodegen generate` once XcodeGen is installed.

