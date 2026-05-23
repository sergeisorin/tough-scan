import SwiftUI
import ToughScanCore
import UIKit

struct LiveScanView: View {
    @Binding var session: ProgressiveScanSession
    @Binding var bestSnapshot: DocumentSnapshot?
    let onReview: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var cameraController = CameraSessionController()
    @State private var hasCameraAccess = false
    @State private var frameProcessor: ScanFrameProcessor?
    @State private var liveScanMessage: String?
    @State private var latestSnapshot: DocumentSnapshot?
    @State private var hasReceivedScanUpdate = false
    @State private var cameraControlState = CameraControlState()
    @State private var automationController = ScanAutomationController()
    @State private var latestFrameQuality: FrameQualityMetrics?
    @State private var messageCoordinator = ScanMessageCoordinator()
    @State private var automationFocusRequest: CameraFocusRequest?
    @State private var imageFusionSession: DocumentImageFusionSession?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ZStack {
                    if hasCameraAccess {
                        CameraPreviewView(
                            session: cameraController.captureSession,
                            onTapDevicePoint: focusCamera,
                            automationFocusRequest: automationFocusRequest
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

                VStack(alignment: .leading, spacing: 8) {
                    Text("Flattened page + confidence grid")
                        .font(.headline)
                    Text("Scan the full page, then revisit gray, red, or orange grid cells until the page is ready.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    NormalizedDocumentPreviewView(
                        snapshot: reviewSnapshot,
                        confidenceMap: session.confidenceMap,
                        showsOverlay: true,
                        targetCoordinate: scanGuidance.targetTile?.coordinate,
                        showsTextLineOverlay: false
                    )
                    .frame(height: 220)
                }
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

                #if DEBUG
                HStack {
                    Button("Debug stronger pass") {
                        addSimulatedFrame()
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .padding(.horizontal, 16)
                #endif
            }
            .padding(.vertical, 16)
        }
        .navigationTitle("Live scan")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            LiveScanActionBar(
                canReviewScan: canReviewScan,
                progressText: progressText,
                liveScanMessage: liveScanMessage,
                onReview: openReview
            )
        }
        .task {
            await prepareCamera()
        }
        .onDisappear {
            cameraController.stop()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                cameraController.start()
            case .background:
                cameraController.stop()
            case .inactive:
                break
            @unknown default:
                break
            }
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
            publishScanMessage(message, priority: .error)
        }
    }

    private var scanGuidance: ScanGuidance {
        session.scanGuidance()
    }

    private var reviewSnapshot: DocumentSnapshot? {
        bestSnapshot ?? latestSnapshot
    }

    private var canReviewScan: Bool {
        reviewSnapshot != nil && scanGuidance.readyForReview
    }

    private var regionsWithDataCount: Int {
        session.confidenceMap.tiles.filter { tile in
            tile.visualQuality > 0 || tile.ocrConfidence > 0 || tile.textCoverage > 0
        }.count
    }

    private var progressText: String {
        if scanGuidance.readyForReview {
            return "Ready: all grid cells are reviewable."
        }

        if hasReceivedScanUpdate {
            return "Scanning: \(regionsWithDataCount) of \(session.confidenceMap.tiles.count) grid cells have evidence."
        }

        return "Waiting for the first flattened page."
    }

    private func prepareCamera() async {
        hasCameraAccess = await cameraController.requestAccess()
        guard hasCameraAccess else {
            publishScanMessage("Camera access is required for live scanning.", priority: .error)
            return
        }

        if frameProcessor == nil {
            imageFusionSession = DocumentImageFusionSession(
                gridWidth: session.confidenceMap.width,
                gridHeight: session.confidenceMap.height
            )
            frameProcessor = ScanFrameProcessor(
                gridWidth: session.confidenceMap.width,
                gridHeight: session.confidenceMap.height,
                onObservation: { observation in
                    hasReceivedScanUpdate = true
                    session.addFrame(observation)
                    publishScanMessage(message(for: session.scanGuidance()), priority: .guidance)
                    if let latestFrameQuality {
                        applyAutomation(metrics: latestFrameQuality)
                    }
                },
                onSnapshot: { snapshot in
                    let recoveredSnapshot = addSnapshotToRecoveredPage(snapshot)
                    latestSnapshot = recoveredSnapshot
                    bestSnapshot = recoveredSnapshot
                },
                onFrameQuality: { metrics in
                    latestFrameQuality = metrics
                },
                onError: { message in
                    publishScanMessage(message, priority: .qualityWarning)
                }
            )
        }

        cameraController.frameConsumer = frameProcessor
        publishScanMessage("Hold the full document in frame so all edges are visible.", priority: .guidance)
        cameraController.configureAndStart()
    }

    private func openReview() {
        if bestSnapshot == nil {
            bestSnapshot = latestSnapshot
        }

        onReview()
    }

    private func addSnapshotToRecoveredPage(_ snapshot: DocumentSnapshot) -> DocumentSnapshot {
        if imageFusionSession == nil {
            imageFusionSession = DocumentImageFusionSession(
                gridWidth: session.confidenceMap.width,
                gridHeight: session.confidenceMap.height
            )
        }

        return imageFusionSession?.add(snapshot) ?? snapshot
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
            publishScanMessage("Camera focus controls are available on iPhone.", priority: .error)
            return
        }

        cameraController.setFocusAndExposurePoint(devicePoint) { _, message in
            publishScanMessage(message, priority: .automation)
        }
    }

    private func updateTorch(isEnabled: Bool) {
        guard cameraController.cameraControlsAvailable else {
            publishScanMessage("Torch controls are available on iPhone.", priority: .error)
            return
        }

        cameraController.setTorch(enabled: isEnabled) { success, message in
            if success {
                cameraControlState.torchEnabled = isEnabled
            }

            publishScanMessage(message, priority: .automation)
        }
    }

    private func updateExposure(_ value: Float) {
        guard cameraController.cameraControlsAvailable else {
            publishScanMessage("Exposure controls are available on iPhone.", priority: .error)
            return
        }

        var requestedState = cameraControlState
        requestedState.setExposureBias(value)

        cameraController.setExposureBias(requestedState.exposureBias) { success, message in
            if success {
                cameraControlState = requestedState
                publishScanMessage(
                    "Exposure set to \(requestedState.exposureLabel.lowercased()).",
                    priority: .automation
                )
            } else {
                publishScanMessage(message, priority: .error)
            }
        }
    }

    private func updateZoom(_ value: CGFloat) {
        guard cameraController.cameraControlsAvailable else {
            publishScanMessage("Zoom controls are available on iPhone.", priority: .error)
            return
        }

        var requestedState = cameraControlState
        requestedState.setZoomFactor(value)

        cameraController.setZoomFactor(requestedState.zoomFactor) { success, message in
            if success {
                cameraControlState = requestedState
            }

            publishScanMessage(message, priority: success ? .automation : .error)
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
            automationFocusRequest = CameraFocusRequest(normalizedPreviewPoint: point)
        case let .setZoom(value):
            updateZoom(value)
        case let .showGuidance(message):
            publishScanMessage(message, priority: .automation)
        }

        if let message = decision.message {
            publishScanMessage(message, priority: .automation)
        }
    }

    private func resetCameraControls() {
        cameraController.resetCameraControls { success, message in
            if success {
                cameraControlState.reset()
            }

            publishScanMessage(message, priority: success ? .automation : .error)
        }
    }

    private func publishScanMessage(_ message: String, priority: ScanMessagePriority) {
        messageCoordinator.submit(message, priority: priority)
        liveScanMessage = messageCoordinator.currentMessage
    }

    #if DEBUG
    private func addSimulatedFrame() {
        hasReceivedScanUpdate = true
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
    #endif
}

private struct LiveScanActionBar: View {
    let canReviewScan: Bool
    let progressText: String
    let liveScanMessage: String?
    let onReview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(liveScanMessage ?? progressText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Review scan", action: onReview)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(!canReviewScan)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.regularMaterial)
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
            Image(systemName: guidance.readyForReview ? "checkmark.circle.fill" : "scope")
                .font(.title3)
                .foregroundStyle(guidance.readyForReview ? .green : .blue)

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
        .background(guidance.readyForReview ? Color.green.opacity(0.12) : Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityHint(guidance.readyForReview ? "Use the Review scan button at the bottom of the screen." : "")
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
            return "Enough evidence has been collected. Use the Review scan button at the bottom of the screen."
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

