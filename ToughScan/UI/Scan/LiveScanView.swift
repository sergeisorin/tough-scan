import SwiftUI
import ToughScanCore
import UIKit

struct LiveScanView: View {
    @Binding var session: ProgressiveScanSession
    @Binding var bestSnapshot: DocumentSnapshot?
    let onReview: () -> Void

    @StateObject private var cameraController = CameraSessionController()
    @State private var hasCameraAccess = false
    @State private var frameProcessor: ScanFrameProcessor?
    @State private var liveScanMessage: String?
    @State private var latestSnapshot: DocumentSnapshot?
    @State private var cameraControlState = CameraControlState()
    @State private var automationController = ScanAutomationController()
    @State private var latestFrameQuality: FrameQualityMetrics?

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                if hasCameraAccess {
                    CameraPreviewView(
                        session: cameraController.captureSession,
                        onTapDevicePoint: focusCamera
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                } else {
                    CameraPreviewPlaceholder()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 460)
            .padding(.horizontal, 16)
            .accessibilityLabel("Live camera preview")

            NormalizedDocumentPreviewView(
                snapshot: bestSnapshot ?? latestSnapshot,
                confidenceMap: session.confidenceMap,
                showsOverlay: true,
                targetCoordinate: scanGuidance.targetTile?.coordinate
            )
            .frame(height: 220)
            .padding(.horizontal, 16)

            ScanGuidancePanel(guidance: scanGuidance)
                .padding(.horizontal, 16)

            CameraAssistPanel(
                state: cameraControlState,
                controlsAvailable: cameraController.cameraControlsAvailable,
                onTorchChanged: updateTorch,
                onExposureChanged: updateExposure,
                onReset: resetCameraControls
            )
            .padding(.horizontal, 16)

            if let liveScanMessage {
                Text(liveScanMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 12) {
                Button("Debug stronger pass") {
                    addSimulatedFrame()
                }
                .buttonStyle(.bordered)

                Button("Review scan", action: onReview)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canReviewScan)
            }
            .controlSize(.large)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .navigationTitle("Live scan")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await prepareCamera()
        }
        .onDisappear {
            cameraController.stop()
        }
        .onReceive(cameraController.$supportedExposureRange) { range in
            cameraControlState = CameraControlState(
                torchEnabled: cameraControlState.torchEnabled,
                exposureBias: cameraControlState.exposureBias,
                supportedExposureRange: range,
                zoomFactor: cameraControlState.zoomFactor,
                supportedZoomRange: cameraControlState.supportedZoomRange
            )
        }
        .onReceive(cameraController.$supportedZoomRange) { range in
            cameraControlState = CameraControlState(
                torchEnabled: cameraControlState.torchEnabled,
                exposureBias: cameraControlState.exposureBias,
                supportedExposureRange: cameraControlState.supportedExposureRange,
                zoomFactor: cameraControlState.zoomFactor,
                supportedZoomRange: range
            )
        }
        .onReceive(cameraController.$currentZoomFactor) { zoomFactor in
            var nextState = cameraControlState
            nextState.setZoomFactor(zoomFactor)
            cameraControlState = nextState
        }
        .onReceive(cameraController.$latestError.compactMap { $0 }) { message in
            liveScanMessage = message
        }
    }

    private var scanGuidance: ScanGuidance {
        session.scanGuidance()
    }

    private var canReviewScan: Bool {
        bestSnapshot != nil && scanGuidance.readyForReview
    }

    private func prepareCamera() async {
        hasCameraAccess = await cameraController.requestAccess()
        guard hasCameraAccess else {
            liveScanMessage = "Camera access is required for live scanning."
            return
        }

        if frameProcessor == nil {
            frameProcessor = ScanFrameProcessor(
                gridWidth: session.confidenceMap.width,
                gridHeight: session.confidenceMap.height,
                onObservation: { observation in
                    session.addFrame(observation)
                    liveScanMessage = message(for: session.scanGuidance())
                    if let latestFrameQuality {
                        applyAutomation(metrics: latestFrameQuality)
                    }
                },
                onSnapshot: { snapshot in
                    latestSnapshot = snapshot
                    if snapshot.isBetterThan(bestSnapshot) {
                        bestSnapshot = snapshot
                    }
                },
                onFrameQuality: { metrics in
                    latestFrameQuality = metrics
                },
                onError: { message in
                    liveScanMessage = message
                }
            )
        }

        cameraController.frameConsumer = frameProcessor
        liveScanMessage = "Hold the full document in frame so all edges are visible."
        cameraController.configure()
        cameraController.start()
    }

    private func message(for guidance: ScanGuidance) -> String {
        switch guidance.action {
        case .scanMissingRegion:
            return "Document flattened. Keep scanning the highlighted missing region."
        case .rescanWeakText:
            return "Document flattened. Revisit the highlighted weak text region."
        case .holdSteady:
            return "Document flattened. Hold steady while the overlay settles."
        case .readyForReview:
            return "Page has enough evidence for review."
        }
    }

    private func focusCamera(at devicePoint: CGPoint) {
        guard cameraController.cameraControlsAvailable else {
            liveScanMessage = "Camera focus controls are available on iPhone."
            return
        }

        cameraController.setFocusAndExposurePoint(devicePoint) { _, message in
            liveScanMessage = message
        }
    }

    private func updateTorch(isEnabled: Bool) {
        guard cameraController.cameraControlsAvailable else {
            liveScanMessage = "Torch controls are available on iPhone."
            return
        }

        cameraController.setTorch(enabled: isEnabled) { success, message in
            if success {
                cameraControlState.torchEnabled = isEnabled
            }

            liveScanMessage = message
        }
    }

    private func updateExposure(_ value: Float) {
        guard cameraController.cameraControlsAvailable else {
            liveScanMessage = "Exposure controls are available on iPhone."
            return
        }

        var requestedState = cameraControlState
        requestedState.setExposureBias(value)

        cameraController.setExposureBias(requestedState.exposureBias) { success, message in
            if success {
                cameraControlState = requestedState
                liveScanMessage = "Exposure set to \(requestedState.exposureLabel.lowercased())."
            } else {
                liveScanMessage = message
            }
        }
    }

    private func updateZoom(_ value: CGFloat) {
        guard cameraController.cameraControlsAvailable else {
            liveScanMessage = "Zoom controls are available on iPhone."
            return
        }

        var requestedState = cameraControlState
        requestedState.setZoomFactor(value)

        cameraController.setZoomFactor(requestedState.zoomFactor) { success, message in
            if success {
                cameraControlState = requestedState
            }

            liveScanMessage = message
        }
    }

    private func applyAutomation(metrics: FrameQualityMetrics) {
        let decision = automationController.nextDecision(
            metrics: metrics,
            guidance: session.scanGuidance(),
            cameraState: cameraControlState
        )

        switch decision.command {
        case .none:
            return
        case .enableTorch:
            updateTorch(isEnabled: true)
        case .disableTorch:
            updateTorch(isEnabled: false)
        case let .setExposureBias(value):
            updateExposure(value)
        case let .focusAt(point):
            focusCamera(at: point)
        case let .setZoom(value):
            updateZoom(value)
        case let .showGuidance(message):
            liveScanMessage = message
        }

        if let message = decision.message {
            liveScanMessage = message
        }
    }

    private func resetCameraControls() {
        cameraController.resetCameraControls { success, message in
            if success {
                cameraControlState.reset()
            }

            liveScanMessage = message
        }
    }

    private func addSimulatedFrame() {
        let weakTiles = session.confidenceMap.weakestTiles(limit: 4)
        let targetCoordinates = weakTiles.isEmpty
            ? [TileCoordinate(column: 0, row: 0)]
            : weakTiles.map(\.coordinate)

        session.addFrame(
            FrameObservation(
                id: UUID().uuidString,
                tileEvidence: targetCoordinates.map { coordinate in
                    TileEvidence(
                        coordinate: coordinate,
                        visualQuality: 0.84,
                        ocrConfidence: 0.78,
                        textCoverage: 0.68
                    )
                },
                recognizedTextBlocks: [
                    RecognizedTextBlock(
                        text: "שלום / Sample",
                        confidence: 0.78,
                        languageCode: "he,en",
                        tileCoordinates: targetCoordinates
                    )
                ]
            )
        )

        if bestSnapshot == nil {
            bestSnapshot = DocumentSnapshot(
                image: makeSimulatedDocumentImage(),
                visualQuality: 0.84
            )
            latestSnapshot = bestSnapshot
        }
    }

    private func makeSimulatedDocumentImage() -> UIImage {
        let size = CGSize(width: 720, height: 960)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.label.setFill()
            context.fill(CGRect(x: 72, y: 120, width: 460, height: 8))
            context.fill(CGRect(x: 72, y: 168, width: 580, height: 8))
            context.fill(CGRect(x: 72, y: 216, width: 520, height: 8))
        }
    }
}

private struct CameraPreviewPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color(red: 0.08, green: 0.09, blue: 0.10))
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: "doc.viewfinder")
                        .font(.largeTitle)
                    Text("Camera preview")
                        .font(.headline)
                    Text("AVFoundation stream connects here")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(Color(red: 0.88, green: 0.90, blue: 0.89))
            }
    }
}

private struct ScanGuidancePanel: View {
    let guidance: ScanGuidance

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "scope")
                .font(.title3)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var title: String {
        switch guidance.action {
        case .scanMissingRegion:
            return "Scan missing region"
        case .rescanWeakText:
            return "Rescan weak text"
        case .holdSteady:
            return "Hold steady"
        case .readyForReview:
            return "Page ready for review"
        }
    }

    private var message: String {
        switch guidance.action {
        case .scanMissingRegion:
            return "Aim at \(targetDescription). Hold the full page steady until the region fills in."
        case .rescanWeakText:
            return "Move back to \(targetDescription) and hold steady for another pass."
        case .holdSteady:
            return "The page is detected. Keep it still while the overlay settles."
        case .readyForReview:
            return "Enough evidence has been collected. Review or add another page."
        }
    }

    private var targetDescription: String {
        guard let tile = guidance.targetTile else {
            return "the highlighted region"
        }

        return "column \(tile.coordinate.column + 1), row \(tile.coordinate.row + 1)"
    }
}

private struct CameraAssistPanel: View {
    let state: CameraControlState
    let controlsAvailable: Bool
    let onTorchChanged: (Bool) -> Void
    let onExposureChanged: (Float) -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Camera assist")
                        .font(.headline)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Reset", action: onReset)
                    .buttonStyle(.bordered)
                    .disabled(!controlsAvailable)
            }

            Toggle(
                "Torch",
                isOn: Binding(
                    get: { state.torchEnabled },
                    set: onTorchChanged
                )
            )
            .disabled(!controlsAvailable)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Exposure")
                    Spacer()
                    Text(state.exposureLabel)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)

                Slider(
                    value: Binding(
                        get: { Double(state.exposureBias) },
                        set: { onExposureChanged(Float($0)) }
                    ),
                    in: Double(state.supportedExposureRange.lowerBound)...Double(state.supportedExposureRange.upperBound)
                )
                .disabled(!controlsAvailable)

                Text("Increase only if text is too dark. Tap the camera preview to set focus and exposure.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var statusText: String {
        controlsAvailable
            ? "Use light and exposure only when the text needs help."
            : "Camera controls are available on iPhone."
    }
}

