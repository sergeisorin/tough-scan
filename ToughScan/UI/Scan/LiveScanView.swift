import SwiftUI
import ToughScanCore

struct LiveScanView: View {
    @Binding var session: ProgressiveScanSession
    @Binding var bestSnapshot: DocumentSnapshot?
    let onReview: () -> Void

    @StateObject private var cameraController = CameraSessionController()
    @State private var hasCameraAccess = false
    @State private var frameProcessor: ScanFrameProcessor?
    @State private var liveScanMessage: String?
    @State private var latestSnapshot: DocumentSnapshot?

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                if hasCameraAccess {
                    CameraPreviewView(session: cameraController.captureSession)
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
                showsOverlay: true
            )
            .frame(height: 220)
            .padding(.horizontal, 16)

            ScanGuidancePanel(tile: session.guidanceSuggestion())
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
                    liveScanMessage = "Document flattened. Live OCR updated \(observation.tileEvidence.count) region(s)."
                },
                onSnapshot: { snapshot in
                    latestSnapshot = snapshot
                    if snapshot.isBetterThan(bestSnapshot) {
                        bestSnapshot = snapshot
                    }
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

    private func addSimulatedFrame() {
        let weakTile = session.guidanceSuggestion()?.coordinate ?? TileCoordinate(column: 0, row: 0)
        session.addFrame(
            FrameObservation(
                id: UUID().uuidString,
                tileEvidence: [
                    TileEvidence(
                        coordinate: weakTile,
                        visualQuality: 0.84,
                        ocrConfidence: 0.78,
                        textCoverage: 0.68
                    )
                ],
                recognizedTextBlocks: [
                    RecognizedTextBlock(
                        text: "שלום / Sample",
                        confidence: 0.78,
                        languageCode: "he,en",
                        tileCoordinates: [weakTile]
                    )
                ]
            )
        )
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
    let tile: ScanTile?

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
        guard let tile else {
            return "Scan is complete"
        }

        switch tile.state {
        case .needsScan:
            return "Scan missing region"
        case .veryUncertain:
            return "Rescan weak text"
        case .uncertain:
            return "Review this area"
        case .successful:
            return "Keep moving steadily"
        }
    }

    private var message: String {
        guard let tile else {
            return "All regions have enough evidence for review."
        }

        return "Aim at column \(tile.coordinate.column + 1), row \(tile.coordinate.row + 1). Hold steady until the overlay settles."
    }
}

