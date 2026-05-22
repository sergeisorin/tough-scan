# Tough Scan Architecture

## Product Direction

Tough Scan is a native iPhone document recovery app. Its purpose is to scan documents that are hard to read, hard to copy, or only available as poor images. The app should help the user recover a usable document image and copyable text, while staying local on the device.

The core architecture is a custom progressive scanner, not a generic camera app and not an Apple Intelligence showcase. New Apple APIs are useful only when they directly improve capture quality, text recovery, document structure, AI-assisted review, or export.

## Conversation Alignment

The earlier project notes established a local AVFoundation, Vision, Core Image, SwiftUI, and Swift Package architecture for progressive OCR. Later discussion explored iOS 26 Vision and Foundation Models APIs. The useful outcome from that exploration is document-specific image analysis: better document structure, table/list/barcode recovery, lens-smudge checks, and non-blocking AI-assisted review.

The current product direction narrows the scope:

- Keep scanning and copy recovery as the primary goal.
- Do not force upgrades for features that are not central to hard-to-read or hard-to-copy documents.
- Treat translation as out of scope.
- Treat Apple Intelligence as a core review capability on supported devices, but not as a prerequisite for scanning, OCR, copy, or export.

## Current Implementation Shape

The app is split into a testable scan domain and an iOS shell:

- `Sources/ToughScanCore/` contains pure Swift models for confidence states, tile confidence maps, recognized text blocks, frame observations, progressive scan sessions, and scan guidance.
- `ToughScan/Camera/` owns AVFoundation capture, camera permission, torch, exposure, focus, and zoom controls.
- `ToughScan/Processing/` owns document detection, perspective normalization, frame quality analysis, lens-smudge detection, image enhancement, OCR, structured document recognition, and local AI-assisted review.
- `ToughScan/UI/Scan/` owns live scanning, confidence overlays, guidance, and camera assist controls.
- `ToughScan/UI/Review/` owns reconstructed document review, selectable image text, recovered OCR text, document structure, AI-assisted review notes, page management, and export entry points.
- `ToughScan/Export/` owns local PDF and text export bundles.
- `ToughScanTests/` covers scan behavior, camera-control state, processing helpers, document intelligence state, review page sets, and export behavior.

The current `project.yml` targets iOS 26. Some code is guarded with compiler and availability checks for newer Vision APIs, but Foundation Models is imported directly in the document-intelligence layer. If broader device support becomes important, AI-assisted review should be isolated behind build settings or target separation before lowering the deployment target.

## Data Flow

1. `CameraSessionController` captures live frames from the back camera and sends them to `ScanFrameProcessor`.
2. `ScanFrameProcessor` detects the document, waits for stable geometry, normalizes perspective, analyzes capture quality, optionally checks lens smudge, enhances the image, and runs OCR.
3. `TileEvidenceMapper` maps recognized text regions and frame quality into tile evidence.
4. `ProgressiveScanSession` fuses stronger observations into the confidence map and merges higher-confidence text blocks.
5. `LiveScanView` displays the camera preview, normalized document preview, confidence overlay, camera assist controls, and guidance for missing or weak regions.
6. `ScanReviewView` shows the best recovered page, text confidence, Live Text image view, structured document output when available, AI-assisted review when available, captured pages, and local export.
7. `ScanExportService` creates a local PDF plus a text file that preserves page order and uses structured text when available.

## Architectural Priorities

- Keep core scan logic testable without camera hardware.
- Keep camera, Vision, image enhancement, OCR, structure recognition, intelligence, and export behind narrow boundaries.
- Prefer local processing. Do not send document images or OCR text to servers.
- Make confidence visible and actionable, not just diagnostic.
- Optimize for document recovery: capture quality, perspective, contrast, OCR confidence, and copyable output.
- Keep iOS 26 AI-assisted review isolated so unavailable intelligence states do not distort the main scanner or block copy/export.

## Development Gaps And Next Steps

1. Validate the live scan pipeline on a real iPhone with hard documents: skewed pages, low contrast, glare, faded ink, Hebrew, English, and mixed content. The simulator cannot prove capture, focus, exposure, lens-smudge, or OCR quality.
2. Remove or hide development-only controls such as `Debug stronger pass` before treating the app as user-facing.
3. Tune frame-quality thresholds with real samples. Brightness, contrast, sharpness, glare, smudge confidence, geometry confidence, text coverage, and OCR confidence need measured thresholds instead of only code-level heuristics.
4. Strengthen copy recovery. The review screen should make it obvious which text is copyable, preserve page and reading order, and export structured text for paragraphs, tables, lists, and barcodes when available.
5. Clarify iOS support. Decide whether the near-term app is iOS 26-only, or whether iOS 26 document structure and intelligence are optional capabilities over a lower baseline scanner.
6. Harden AI-assisted review. Summaries, key-detail extraction, and cleaned-text suggestions are core review capabilities on supported devices, but must remain advisory, local, clearly labeled, and excluded from export unless the user opts in.
7. Align documentation and validation. `README.md` should separate basic scan validation from supported-device Apple Intelligence capability validation.
8. Add privacy and logging checks. OCR text, document images, intelligence prompts, generated notes, and extracted PII must not appear in logs.
9. Broaden automated checks around review and export behavior: multi-page ordering, page removal, stale structured documents, stale intelligence results, empty OCR, and failed export cleanup.
10. Create a small real-world test corpus of difficult documents for repeatable manual validation: blurred print, low light, glare, creases, small fonts, tables, forms, receipts, Hebrew, English, and mixed-language pages.

## Non-Core Or Deferred Architecture

- Translation is not part of the current product architecture.
- Cloud OCR, sync, accounts, and server storage are out of scope.
- Generic image/video classification is out of scope unless it directly improves document capture or text recovery.
- Apple Intelligence should not be required for scanning, OCR, copy, or export.

