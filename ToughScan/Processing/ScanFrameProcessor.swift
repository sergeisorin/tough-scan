import AVFoundation
import CoreImage
import Foundation
import ToughScanCore
import UIKit

final class ScanFrameProcessor: CameraFrameConsumer {
    typealias ObservationHandler = @MainActor (FrameObservation) -> Void
    typealias SnapshotHandler = @MainActor (DocumentSnapshot) -> Void
    typealias ErrorHandler = @MainActor (String) -> Void

    private let mapper: TileEvidenceMapper
    private let imageEnhancer: ImageEnhancer
    private let textRecognizer: TextRecognitionService
    private let documentDetector: DocumentDetecting
    private let perspectiveNormalizer: PerspectiveNormalizing
    private let minimumFrameInterval: TimeInterval
    private let processingQueue = DispatchQueue(label: "com.local.toughscan.scan-frame-processor")
    private let stateLock = NSLock()
    private let onObservation: ObservationHandler
    private let onSnapshot: SnapshotHandler?
    private let onError: ErrorHandler?

    private var isProcessing = false
    private var lastAcceptedFrameTime: TimeInterval = 0
    private var geometryStabilizer: DocumentGeometryStabilizer

    init(
        gridWidth: Int,
        gridHeight: Int,
        framesPerSecond: Double = 3,
        imageEnhancer: ImageEnhancer = ImageEnhancer(),
        textRecognizer: TextRecognitionService = TextRecognitionService(),
        documentDetector: DocumentDetecting = DocumentDetectionService(),
        perspectiveNormalizer: PerspectiveNormalizing = PerspectiveNormalizer(),
        geometryStabilizer: DocumentGeometryStabilizer = DocumentGeometryStabilizer(),
        onObservation: @escaping ObservationHandler,
        onSnapshot: SnapshotHandler? = nil,
        onError: ErrorHandler? = nil
    ) {
        self.mapper = TileEvidenceMapper(gridWidth: gridWidth, gridHeight: gridHeight)
        self.imageEnhancer = imageEnhancer
        self.textRecognizer = textRecognizer
        self.documentDetector = documentDetector
        self.perspectiveNormalizer = perspectiveNormalizer
        self.geometryStabilizer = geometryStabilizer
        self.minimumFrameInterval = 1 / max(framesPerSecond, 1)
        self.onObservation = onObservation
        self.onSnapshot = onSnapshot
        self.onError = onError
    }

    func cameraSession(_ session: CameraSessionController, didOutput sampleBuffer: CMSampleBuffer) {
        guard reserveProcessingSlot() else {
            return
        }

        processingQueue.async { [weak self] in
            guard let self else {
                return
            }

            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                self.finishProcessing()
                return
            }

            let sourceImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(.right)

            Task { [weak self] in
                guard let self else {
                    return
                }

                defer {
                    self.finishProcessing()
                }

                do {
                    let detectedGeometry = try await self.documentDetector.detectDocument(in: sourceImage)
                    let stableGeometry = self.updateStableGeometry(with: detectedGeometry)

                    guard let stableGeometry else {
                        await self.onError?("Hold document edges in frame.")
                        return
                    }

                    guard let normalizedImage = self.perspectiveNormalizer.normalize(
                        sourceImage,
                        quad: stableGeometry.quad
                    ) else {
                        await self.onError?("Hold steady while the document is flattened.")
                        return
                    }

                    let enhancedImage = self.imageEnhancer.enhance(normalizedImage)

                    guard let cgImage = self.imageEnhancer.makeCGImage(from: enhancedImage) else {
                        await self.onError?("Could not prepare document image for OCR.")
                        return
                    }

                    let visualQuality = self.estimateVisualQuality(
                        from: enhancedImage,
                        geometryConfidence: stableGeometry.confidence
                    )
                    let regions = try await self.textRecognizer.recognizeTextRegions(in: cgImage)
                    let mapped = self.mapper.map(regions: regions, visualQuality: visualQuality)

                    guard !mapped.tileEvidence.isEmpty || !mapped.recognizedTextBlocks.isEmpty else {
                        return
                    }

                    let snapshot = DocumentSnapshot(
                        image: UIImage(cgImage: cgImage),
                        visualQuality: visualQuality
                    )
                    let observation = FrameObservation(
                        id: UUID().uuidString,
                        tileEvidence: mapped.tileEvidence,
                        recognizedTextBlocks: mapped.recognizedTextBlocks
                    )

                    await self.onSnapshot?(snapshot)
                    await self.onObservation(observation)
                } catch {
                    await self.onError?("Live OCR failed. Keep scanning or try better light.")
                }
            }
        }
    }

    private func reserveProcessingSlot() -> Bool {
        stateLock.lock()
        defer {
            stateLock.unlock()
        }

        let now = ProcessInfo.processInfo.systemUptime
        guard !isProcessing, now - lastAcceptedFrameTime >= minimumFrameInterval else {
            return false
        }

        isProcessing = true
        lastAcceptedFrameTime = now
        return true
    }

    private func finishProcessing() {
        stateLock.lock()
        isProcessing = false
        stateLock.unlock()
    }

    private func updateStableGeometry(with observation: DocumentGeometryObservation?) -> DocumentGeometryObservation? {
        stateLock.lock()
        defer {
            stateLock.unlock()
        }

        return geometryStabilizer.update(with: observation)
    }

    private func estimateVisualQuality(
        from image: CIImage,
        geometryConfidence: Double
    ) -> Double {
        let area = max(image.extent.width * image.extent.height, 1)
        let megapixels = area / 1_000_000
        let imageQuality = min(0.85, max(0.55, megapixels / 3))
        return min(max((imageQuality * 0.70) + (geometryConfidence * 0.30), 0), 1)
    }
}

