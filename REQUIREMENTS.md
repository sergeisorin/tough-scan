# Tough Scan Requirements

## Goal

Tough Scan helps users recover documents that are hard to read and hard to copy. A successful scan produces a readable document image, copyable recovered text, visible confidence for weak areas, and a local export the user can keep or share.

The product should feel like a document recovery instrument: calm, precise, and focused on improving the result until the user can read and copy what matters.

## Primary Users

- People with printed documents that are faded, low contrast, skewed, glared, creased, or photographed poorly.
- People who have a document image or scan where text is visible but not selectable.
- People handling personal documents who need local processing and clear confidence about what was recovered.

## Core Requirements

1. The app must scan printed documents with the iPhone camera.
2. The app must detect the document boundary and normalize perspective before OCR.
3. The app must improve document readability through local image enhancement.
4. The app must extract copyable text locally from the recovered document image.
5. The app must support Hebrew and English OCR as first-class languages.
6. The app must progressively combine multiple camera observations into a better result.
7. The app must show confidence states for document regions and recovered text.
8. The app must guide users back to missing or weak regions instead of making them guess what to rescan.
9. The app must let users review the reconstructed document before export.
10. The app must export local results as PDF and text files.
11. The app must support multi-page scan sets for export.
12. The app must keep document images, OCR text, and generated notes on device.

## Copy-Recovery Requirements

1. Recovered OCR text must be displayed in review with confidence information.
2. Users must be able to select or copy recovered text from the review experience.
3. The exported text file must preserve page order.
4. When structured document recognition is available, exported text should prefer structured paragraphs, tables, lists, and barcodes over a flat OCR dump.
5. Tables should be exported in a copy-friendly format such as tab-separated text.
6. Empty or weak OCR areas must remain visible as quality gaps, not silently disappear.
7. The app must not require translation to make text copyable.

## Capture And Guidance Requirements

1. The app must ask the user to keep all document edges in frame when geometry is missing or unstable.
2. The app must warn or guide when capture quality is weak because of low light, glare, blur, poor contrast, poor coverage, or possible lens smudge.
3. The app should use camera controls such as focus, exposure, torch, and zoom only to improve document recovery.
4. The app should avoid over-capturing every frame; frame processing should be throttled enough to keep the UI responsive.
5. The app must allow rescanning weak areas without discarding already-good evidence.

## Review And Export Requirements

1. Review must show the best recovered document image with confidence overlay.
2. Review must show recovered text with confidence labels.
3. Review must show document structure when local structured recognition succeeds.
4. Review must allow adding another page to the current export set.
5. Review must allow removing captured pages from the export set.
6. Export must fail cleanly if no page is ready.
7. Export must clean up temporary files after sharing.
8. Export must not include optional intelligence notes unless the user explicitly enables that option.

## AI-Assisted Review Capability

Apple Intelligence and Foundation Models are core review capabilities on supported devices. They help users interpret and clean recovered text from hard-to-read documents after local OCR or structured recognition has produced source text. They provide:

- A concise summary of recovered text.
- Extracted key details.
- A cleaned OCR-text suggestion that preserves uncertainty.

These features must be local, clearly labeled as advisory, unavailable without blocking scan, OCR, copy, or export, and excluded from export unless the user opts in. Unsupported devices, disabled Apple Intelligence, unavailable model assets, unsupported locales, and empty recovered-text states are graceful review limitations, not app failures.

## Non-Goals

- Translation.
- Cloud OCR or server-side document processing.
- User accounts, sync, or document library management.
- Handwriting recognition in the MVP.
- Generic photo/video analysis unrelated to document recovery.
- Making Apple Intelligence a prerequisite for scanning, OCR, copy, or export.
- Storing or logging document content, OCR text, extracted PII, prompts, or generated notes.

## Current Status Compared With Prior Work

The implemented app already covers more than the original MVP scaffold:

- Pure Swift scan-domain logic and checks exist.
- AVFoundation camera capture and camera controls exist.
- Vision document detection, perspective normalization, image enhancement, OCR, and confidence mapping exist.
- Frame quality analysis, camera assist, and lens-smudge detection are present.
- Review includes confidence overlays, recovered text, Live Text image display, structured document output, multi-page export, and local AI-assisted review notes on supported devices.
- PDF and text export bundles exist.
- Unit tests cover many core, processing, export, and optional-intelligence behaviors.

The requirements have been refocused from the later "iOS 26-first upgrade" conversation. iOS 26 APIs can help, but they should not define the product. Translation is not relevant to the current goal.

## Gaps And Next Development Steps

1. Run real-device validation on difficult documents. Confirm camera capture, geometry stabilization, OCR quality, guidance, structured recognition, export, and privacy behavior on an actual iPhone.
2. Build a small validation set of hard-to-read and hard-to-copy documents: faded print, small fonts, low light, glare, blur, skew, creases, forms, tables, receipts, Hebrew, English, and mixed-language pages.
3. Tune confidence and quality thresholds using that validation set. The app needs product-level definitions for "ready for review", "weak text", "missing region", and "rescan needed".
4. Improve the review copy workflow. Make copyable recovered text and structured text easier to inspect, select, and trust.
5. Decide the platform baseline. If wider support matters, isolate iOS 26-only AI-assisted review from the core scanner while keeping scan, OCR, copy, and export available without Apple Intelligence.
6. Remove development-only UI before user testing, especially the simulated stronger-pass control.
7. Tighten export behavior for edge cases: empty OCR, partially structured pages, deleted pages, stale review data, failed temporary-file writes, and optional notes.
8. Add privacy tests and manual checks to ensure OCR text, document images, extracted details, and generated notes are never logged.
9. Reconcile README validation with this scope. Apple Intelligence validation should be clearly labeled as supported-device capability validation, separate from the basic scan-validation path.
10. After validation, prioritize the next feature by evidence: either capture-quality tuning, copy/review improvements, structured export, or platform-baseline cleanup.

