import AVFoundation
import CoreImage
import Foundation
import ToughScanCore
import UIKit

final class ScanFrameProcessor: CameraFrameConsumer {
    typealias ObservationHandler = @MainActor (FrameObservation) -> Void
    typealias SnapshotHandler = @MainActor (DocumentSnapshot) -> Void
    typealias FrameQualityHandler = @MainActor (FrameQualityMetrics) -> Void
    typealias ErrorHandler = @MainActor (String) -> Void

    private let mapper: TileEvidenceMapper
    private let imageEnhancer: ImageEnhancer
    private let frameQualityAnalyzer: FrameQualityAnalyzing
    private let textRecognizer: TextRecognitionService
    private let documentDetector: DocumentDetecting
    private let perspectiveNormalizer: PerspectiveNormalizing
    private let minimumFrameInterval: TimeInterval
    private let processingQueue = DispatchQueue(label: "com.local.toughscan.scan-frame-processor")
    private let stateLock = NSLock()
    private let onObservation: ObservationHandler
    private let onSnapshot: SnapshotHandler?
    private let onFrameQuality: FrameQualityHandler?
    private let onError: ErrorHandler?

    private var isProcessing = false
    private var lastAcceptedFrameTime: TimeInterval = 0
    private var geometryStabilizer: DocumentGeometryStabilizer

    init(
        gridWidth: Int,
        gridHeight: Int,
        framesPerSecond: Double = 3,
        imageEnhancer: ImageEnhancer = ImageEnhancer(),
        frameQualityAnalyzer: FrameQualityAnalyzing = FrameQualityAnalyzer(),
        textRecognizer: TextRecognitionService = TextRecognitionService(),
        documentDetector: DocumentDetecting = DocumentDetectionService(),
        perspectiveNormalizer: PerspectiveNormalizing = PerspectiveNormalizer(),
        geometryStabilizer: DocumentGeometryStabilizer = DocumentGeometryStabilizer(),
        onObservation: @escaping ObservationHandler,
        onSnapshot: SnapshotHandler? = nil,
        onFrameQuality: FrameQualityHandler? = nil,
        onError: ErrorHandler? = nil
    ) {
        self.mapper = TileEvidenceMapper(gridWidth: gridWidth, gridHeight: gridHeight)
        self.imageEnhancer = imageEnhancer
        self.frameQualityAnalyzer = frameQualityAnalyzer
        self.textRecognizer = textRecognizer
        self.documentDetector = documentDetector
        self.perspectiveNormalizer = perspectiveNormalizer
        self.geometryStabilizer = geometryStabilizer
        self.minimumFrameInterval = 1 / max(framesPerSecond, 1)
        self.onObservation = onObservation
        self.onSnapshot = onSnapshot
        self.onFrameQuality = onFrameQuality
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

                    let qualityMetrics = self.frameQualityAnalyzer.analyze(
                        normalizedImage,
                        geometryConfidence: stableGeometry.confidence,
                        documentCoverage: stableGeometry.quad.area
                    )
                    await self.onFrameQuality?(qualityMetrics)

                    let enhancedImage = self.imageEnhancer.enhance(normalizedImage, metrics: qualityMetrics)

                    guard let cgImage = self.imageEnhancer.makeCGImage(from: enhancedImage) else {
                        await self.onError?("Could not prepare document image for OCR.")
                        return
                    }

                    let visualQuality = qualityMetrics.captureScore
                    let regions = try await self.textRecognizer.recognizeTextRegions(in: cgImage)
                    let mapped = self.mapper.map(regions: regions, visualQuality: visualQuality)

                    guard !mapped.tileEvidence.isEmpty || !mapped.recognizedTextBlocks.isEmpty else {
                        return
                    }

                    let snapshot = DocumentSnapshot(
                        image: UIImage(cgImage: cgImage),
                        visualQuality: visualQuality,
                        captureScore: self.captureScore(
                            qualityMetrics: qualityMetrics,
                            regions: regions,
                            tileEvidence: mapped.tileEvidence
                        ),
                        averageOCRConfidence: self.averageOCRConfidence(in: regions),
                        textCoverage: self.averageTextCoverage(in: mapped.tileEvidence)
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

    private func captureScore(
        qualityMetrics: FrameQualityMetrics,
        regions: [NormalizedTextRegion],
        tileEvidence: [TileEvidence]
    ) -> Double {
        let ocrConfidence = averageOCRConfidence(in: regions)
        let textCoverage = averageTextCoverage(in: tileEvidence)

        return ((qualityMetrics.captureScore * 0.55) + (ocrConfidence * 0.30) + (textCoverage * 0.15))
            .clampedToUnitRange
    }

    private func averageOCRConfidence(in regions: [NormalizedTextRegion]) -> Double {
        guard !regions.isEmpty else {
            return 0
        }

        return (regions.reduce(0) { $0 + $1.confidence } / Double(regions.count)).clampedToUnitRange
    }

    private func averageTextCoverage(in tileEvidence: [TileEvidence]) -> Double {
        guard !tileEvidence.isEmpty else {
            return 0
        }

        return (tileEvidence.reduce(0) { $0 + $1.textCoverage } / Double(tileEvidence.count)).clampedToUnitRange
    }

}

