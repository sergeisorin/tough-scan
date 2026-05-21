# Tough Scan Design Spec

## Summary

Tough Scan is a native iPhone app that recovers hard-to-read printed documents through progressive scanning. It uses the camera stream to collect multiple observations, improves document regions over time, extracts Hebrew and English text locally, and shows confidence overlays that make weak areas explicit.

## Audience

The first audience is people recovering hard-to-read personal documents. They may be anxious, focused, or working with documents that are difficult to replace. The app must feel calm, clinical, and precise.

## Core Capabilities

- Custom progressive camera capture.
- Local-only document processing.
- Printed Hebrew and English OCR.
- Region-level confidence map.
- Word/line-level OCR confidence.
- Guided rescanning for weak regions.
- Local export of reconstructed document and text.

## Scan Flow

1. User starts a scan.
2. Camera frames are evaluated continuously.
3. Document geometry is detected and normalized.
4. Local enhancement improves text contrast and readability.
5. OCR extracts Hebrew and English text where possible.
6. Progressive fusion updates the confidence map.
7. The live UI guides the user to weak regions.
8. Review UI shows the reconstructed document, text, and confidence states.
9. User rescans weak regions or exports the local result.

## UX Direction

The app is a recovery instrument, not a camera app. The live scan screen should keep visual weight on the document and use restrained overlays. Status language should be short and concrete, such as "Lower right needs another pass" or "Text line uncertain."

Confidence states must be visible through more than color:

- Successful: stable area, clear label.
- Uncertain: review label and subtle pattern.
- Very uncertain: stronger warning label and rescan suggestion.
- Needs scan: empty/missing treatment and direct guidance.

## Architecture

The app is split into testable layers:

- Core scan domain: pure Swift models and algorithms.
- Camera layer: AVFoundation permissions, capture session, camera controls.
- Processing layer: document detection, perspective normalization, image enhancement, OCR.
- Fusion layer: combines observations into region and text confidence.
- UI layer: SwiftUI screens and UIKit camera preview integration.
- Export layer: local PDF/image/text output.

## Testing

Use TDD for core behavior:

- Confidence state thresholds.
- Tile map updates.
- Progressive fusion rules.
- Weak-region ranking.
- OCR language configuration models.
- Coordinate mapping.

Camera and Vision integration require device testing on iPhone 15 Pro after the scaffold compiles.

## Non-Goals

- Handwriting in the MVP.
- Cloud sync or server processing.
- Accounts or monetization.
- Production custom Core ML training.
- Full document library management.

