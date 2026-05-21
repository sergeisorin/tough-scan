import AVFoundation
import CoreImage
import Foundation
import ToughScanCore

final class ScanFrameProcessor: CameraFrameConsumer {
    typealias ObservationHandler = @MainActor (FrameObservation) -> Void
    typealias ErrorHandler = @MainActor (String) -> Void

    private let mapper: TileEvidenceMapper
    private let imageEnhancer: ImageEnhancer
    private let textRecognizer: TextRecognitionService
    private let minimumFrameInterval: TimeInterval
    private let processingQueue = DispatchQueue(label: "com.local.toughscan.scan-frame-processor")
    private let stateLock = NSLock()
    private let onObservation: ObservationHandler
    private let onError: ErrorHandler?

    private var isProcessing = false
    private var lastAcceptedFrameTime: TimeInterval = 0

    init(
        gridWidth: Int,
        gridHeight: Int,
        framesPerSecond: Double = 3,
        imageEnhancer: ImageEnhancer = ImageEnhancer(),
        textRecognizer: TextRecognitionService = TextRecognitionService(),
        onObservation: @escaping ObservationHandler,
        onError: ErrorHandler? = nil
    ) {
        self.mapper = TileEvidenceMapper(gridWidth: gridWidth, gridHeight: gridHeight)
        self.imageEnhancer = imageEnhancer
        self.textRecognizer = textRecognizer
        self.minimumFrameInterval = 1 / max(framesPerSecond, 1)
        self.onObservation = onObservation
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
            let enhancedImage = self.imageEnhancer.enhance(sourceImage)

            guard let cgImage = self.imageEnhancer.makeCGImage(from: enhancedImage) else {
                self.finishProcessing()
                return
            }

            let visualQuality = self.estimateVisualQuality(from: enhancedImage)

            Task { [weak self] in
                guard let self else {
                    return
                }

                defer {
                    self.finishProcessing()
                }

                do {
                    let regions = try await self.textRecognizer.recognizeTextRegions(in: cgImage)
                    let mapped = self.mapper.map(regions: regions, visualQuality: visualQuality)

                    guard !mapped.tileEvidence.isEmpty || !mapped.recognizedTextBlocks.isEmpty else {
                        return
                    }

                    let observation = FrameObservation(
                        id: UUID().uuidString,
                        tileEvidence: mapped.tileEvidence,
                        recognizedTextBlocks: mapped.recognizedTextBlocks
                    )

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

    private func estimateVisualQuality(from image: CIImage) -> Double {
        let area = max(image.extent.width * image.extent.height, 1)
        let megapixels = area / 1_000_000
        return min(0.85, max(0.55, megapixels / 3))
    }
}

