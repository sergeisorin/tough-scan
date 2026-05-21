# Tough Scan MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native iPhone MVP scaffold for progressive local document scanning with confidence maps and Hebrew/English OCR boundaries.

**Architecture:** Put scan-domain logic in a pure Swift package first, then wire it into a SwiftUI iOS app scaffold. Keep camera, OCR, image enhancement, and export behind protocols so the progressive scan engine can be tested without device hardware.

**Tech Stack:** Swift, Swift Package Manager, Swift executable checks, SwiftUI, AVFoundation, Vision, Core Image, XcodeGen.

---

## File Structure

- `Package.swift`: Swift package for testable core logic.
- `Sources/ToughScanCore/`: pure Swift scan-domain models and algorithms.
- `Sources/ToughScanCoreChecks/`: executable behavior checks for confidence and fusion behavior.
- `project.yml`: XcodeGen iOS app project definition.
- `ToughScan/App/`: app entry point.
- `ToughScan/UI/`: SwiftUI screens.
- `ToughScan/Camera/`: AVFoundation service shells.
- `ToughScan/Processing/`: Vision/Core Image service shells.
- `ToughScan/Export/`: local export shell.

## Task 1: Core Confidence Domain

**Files:**
- Create: `Package.swift`
- Create: `Sources/ToughScanCore/ScanConfidenceState.swift`
- Create: `Sources/ToughScanCore/TileCoordinate.swift`
- Create: `Sources/ToughScanCore/ScanTile.swift`
- Create: `Sources/ToughScanCore/TileConfidenceMap.swift`
- Check: `Sources/ToughScanCoreChecks/main.swift`

- [ ] **Step 1: Write failing tests**

```swift
func testTileStateUsesCombinedVisualAndOCRConfidence()
func testWeakestTilesAreRankedWithNeedsScanFirst()
func testUpdatingTileKeepsTheStrongerObservation()
```

- [ ] **Step 2: Run tests**

Run: `swift run ToughScanCoreChecks`
Expected: fail because core types do not exist.

- [ ] **Step 3: Implement minimal confidence model**

Define four confidence states, immutable tile coordinates, scan tiles, and a map that updates tiles only when the new observation is stronger.

- [ ] **Step 4: Verify**

Run: `swift run ToughScanCoreChecks`
Expected: pass.

## Task 2: Progressive Scan Session

**Files:**
- Create: `Sources/ToughScanCore/FrameObservation.swift`
- Create: `Sources/ToughScanCore/RecognizedTextBlock.swift`
- Create: `Sources/ToughScanCore/ProgressiveScanSession.swift`
- Check: `Sources/ToughScanCoreChecks/main.swift`

- [ ] **Step 1: Write failing tests**

```swift
func testSessionStartsWithAllTilesNeedingScan()
func testAddingFrameImprovesCoveredTiles()
func testGuidanceReturnsMostImportantWeakRegion()
```

- [ ] **Step 2: Run tests**

Run: `swift run ToughScanCoreChecks`
Expected: fail because session types do not exist.

- [ ] **Step 3: Implement minimal session**

Create a session with a fixed tile grid, accept frame observations, fuse per-tile evidence, and return weak-region guidance.

- [ ] **Step 4: Verify**

Run: `swift run ToughScanCoreChecks`
Expected: pass.

## Task 3: iOS App Scaffold

**Files:**
- Create: `project.yml`
- Create: `ToughScan/App/ToughScanApp.swift`
- Create: `ToughScan/UI/RootView.swift`
- Create: `ToughScan/UI/Scan/LiveScanView.swift`
- Create: `ToughScan/UI/Review/ScanReviewView.swift`

- [ ] **Step 1: Add app scaffold**

Create a SwiftUI shell with Start, Live Scan, and Review states. The UI should use real confidence states from `ToughScanCore`.

- [ ] **Step 2: Generate project**

Run: `xcodegen generate`
Expected: `.xcodeproj` generated if XcodeGen is installed.

## Task 4: Native Service Shells

**Files:**
- Create: `ToughScan/Camera/CameraSessionController.swift`
- Create: `ToughScan/Processing/TextRecognitionService.swift`
- Create: `ToughScan/Processing/ImageEnhancer.swift`
- Create: `ToughScan/Export/ScanExportService.swift`

- [ ] **Step 1: Add protocol-first service shells**

Define AVFoundation, Vision, Core Image, and export boundaries without putting scan logic into UI views.

- [ ] **Step 2: Compile in Xcode**

Open generated project and compile on iPhone 15 Pro simulator or device.

## Task 5: Device Validation

**Files:**
- Modify: `MEMORY.md`

- [ ] **Step 1: Run local tests**

Run: `swift run ToughScanCoreChecks`
Expected: all core checks pass.

- [ ] **Step 2: Validate on device**

Run the app on iPhone 15 Pro and record camera, OCR language, and low-light behavior findings in `MEMORY.md`.

