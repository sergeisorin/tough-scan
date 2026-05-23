import AVFoundation
import Combine
import CoreGraphics
import Foundation

protocol CameraFrameConsumer: AnyObject {
    func cameraSession(_ session: CameraSessionController, didOutput sampleBuffer: CMSampleBuffer)
}

typealias CameraControlCompletion = (Bool, String) -> Void

final class CameraSessionController: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: AVAuthorizationStatus
    @Published private(set) var isRunning = false
    @Published private(set) var latestError: String?
    @Published private(set) var cameraControlsAvailable = false
    @Published private(set) var supportedExposureRange: ClosedRange<Float> = -2...2
    @Published private(set) var supportedZoomRange: ClosedRange<CGFloat> = 1...1
    @Published private(set) var currentZoomFactor: CGFloat = 1

    let captureSession = AVCaptureSession()

    weak var frameConsumer: CameraFrameConsumer?

    private let sessionQueue = DispatchQueue(label: "com.local.toughscan.camera-session")
    private let videoOutput = AVCaptureVideoDataOutput()
    private var isSessionConfigured = false

    override init() {
        self.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        super.init()
    }

    func requestAccess() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        await MainActor.run {
            authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }
        return granted
    }

    func configureAndStart() {
        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }

            guard self.isSessionConfigured || self.performConfiguration() else {
                return
            }

            self.startRunningIfNeeded()
        }
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self, self.isSessionConfigured else {
                return
            }

            self.startRunningIfNeeded()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.captureSession.isRunning else {
                return
            }

            self.captureSession.stopRunning()
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }

    func setTorch(enabled: Bool, completion: CameraControlCompletion? = nil) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentVideoDevice(), device.hasTorch else {
                self?.publishCameraControlResult(
                    success: false,
                    message: "Torch is not available on this camera.",
                    completion: completion
                )
                return
            }

            do {
                try device.lockForConfiguration()
                defer {
                    device.unlockForConfiguration()
                }

                device.torchMode = enabled ? .on : .off
                self.publishCameraControlResult(
                    success: true,
                    message: enabled ? "Torch enabled for low-light text." : "Torch disabled.",
                    completion: completion
                )
            } catch {
                self.publishCameraControlResult(
                    success: false,
                    message: "Torch could not be changed.",
                    completion: completion
                )
            }
        }
    }

    func setExposureBias(_ bias: Float, completion: CameraControlCompletion? = nil) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentVideoDevice() else {
                self?.publishCameraControlResult(
                    success: false,
                    message: "Camera controls are available on iPhone.",
                    completion: completion
                )
                return
            }

            guard device.isExposureModeSupported(.continuousAutoExposure) else {
                self.publishCameraControlResult(
                    success: false,
                    message: "Exposure adjustment is not available on this camera.",
                    completion: completion
                )
                return
            }

            do {
                try device.lockForConfiguration()
                defer {
                    device.unlockForConfiguration()
                }

                let clampedBias = min(max(bias, device.minExposureTargetBias), device.maxExposureTargetBias)
                device.exposureMode = .continuousAutoExposure
                device.setExposureTargetBias(clampedBias, completionHandler: nil)
                self.publishCameraControlResult(
                    success: true,
                    message: "Exposure adjusted.",
                    completion: completion
                )
            } catch {
                self.publishCameraControlResult(
                    success: false,
                    message: "Exposure could not be changed.",
                    completion: completion
                )
            }
        }
    }

    func setFocusAndExposurePoint(_ point: CGPoint, completion: CameraControlCompletion? = nil) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentVideoDevice() else {
                self?.publishCameraControlResult(
                    success: false,
                    message: "Camera controls are available on iPhone.",
                    completion: completion
                )
                return
            }

            let normalizedPoint = CGPoint(
                x: min(max(point.x, 0), 1),
                y: min(max(point.y, 0), 1)
            )

            do {
                try device.lockForConfiguration()
                defer {
                    device.unlockForConfiguration()
                }

                var didApplyControl = false

                if device.isFocusPointOfInterestSupported,
                   device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusPointOfInterest = normalizedPoint
                    device.focusMode = .continuousAutoFocus
                    didApplyControl = true
                }

                if device.isExposurePointOfInterestSupported,
                   device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposurePointOfInterest = normalizedPoint
                    device.exposureMode = .continuousAutoExposure
                    didApplyControl = true
                }

                self.publishCameraControlResult(
                    success: didApplyControl,
                    message: didApplyControl
                        ? "Focus and exposure set for the tapped region."
                        : "Focus and exposure points are not available on this camera.",
                    completion: completion
                )
            } catch {
                self.publishCameraControlResult(
                    success: false,
                    message: "Focus and exposure could not be changed.",
                    completion: completion
                )
            }
        }
    }

    func setZoomFactor(_ zoomFactor: CGFloat, completion: CameraControlCompletion? = nil) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentVideoDevice() else {
                self?.publishCameraControlResult(
                    success: false,
                    message: "Camera zoom is available on iPhone.",
                    completion: completion
                )
                return
            }

            do {
                try device.lockForConfiguration()
                defer {
                    device.unlockForConfiguration()
                }

                let range = self.supportedAutonomousZoomRange(for: device)
                let clampedZoom = min(max(zoomFactor, range.lowerBound), range.upperBound)

                if device.isRampingVideoZoom {
                    device.cancelVideoZoomRamp()
                }

                device.ramp(toVideoZoomFactor: clampedZoom, withRate: 4)
                DispatchQueue.main.async {
                    self.currentZoomFactor = clampedZoom
                }
                self.publishCameraControlResult(
                    success: true,
                    message: clampedZoom > 1 ? "Zooming in for small text." : "Zoom reset.",
                    completion: completion
                )
            } catch {
                self.publishCameraControlResult(
                    success: false,
                    message: "Zoom could not be changed.",
                    completion: completion
                )
            }
        }
    }

    func resetCameraControls(completion: CameraControlCompletion? = nil) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentVideoDevice() else {
                self?.publishCameraControlResult(
                    success: false,
                    message: "Camera controls are available on iPhone.",
                    completion: completion
                )
                return
            }

            do {
                try device.lockForConfiguration()
                defer {
                    device.unlockForConfiguration()
                }

                if device.hasTorch {
                    device.torchMode = .off
                }

                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }

                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                    device.setExposureTargetBias(0, completionHandler: nil)
                }

                if device.isRampingVideoZoom {
                    device.cancelVideoZoomRamp()
                }
                device.videoZoomFactor = self.supportedAutonomousZoomRange(for: device).lowerBound
                DispatchQueue.main.async {
                    self.currentZoomFactor = 1
                }

                self.publishCameraControlResult(
                    success: true,
                    message: "Camera controls reset to auto.",
                    completion: completion
                )
            } catch {
                self.publishCameraControlResult(
                    success: false,
                    message: "Camera controls could not be reset.",
                    completion: completion
                )
            }
        }
    }

    private func currentVideoDevice() -> AVCaptureDevice? {
        (captureSession.inputs.first as? AVCaptureDeviceInput)?.device
    }

    private func supportedAutonomousZoomRange(for device: AVCaptureDevice) -> ClosedRange<CGFloat> {
        let lowerBound = max(device.minAvailableVideoZoomFactor, 1)
        let hardwareUpperBound = max(lowerBound, device.maxAvailableVideoZoomFactor)
        let upperBound = min(hardwareUpperBound, 2)

        return lowerBound...upperBound
    }

    private func performConfiguration() -> Bool {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        defer {
            captureSession.commitConfiguration()
        }

        captureSession.inputs.forEach(captureSession.removeInput)
        captureSession.outputs.forEach(captureSession.removeOutput)

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else {
            publishCameraControlSupport(isAvailable: false)
            publishError("Back camera is not available.")
            isSessionConfigured = false
            return false
        }

        captureSession.addInput(input)
        publishCameraControlSupport(
            isAvailable: true,
            exposureRange: device.minExposureTargetBias...device.maxExposureTargetBias,
            zoomRange: supportedAutonomousZoomRange(for: device)
        )

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)

        guard captureSession.canAddOutput(videoOutput) else {
            publishError("Camera frame output is not available.")
            isSessionConfigured = false
            return false
        }

        captureSession.addOutput(videoOutput)

        if let connection = videoOutput.connection(with: .video),
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }

        isSessionConfigured = true
        return true
    }

    private func startRunningIfNeeded() {
        guard !captureSession.isRunning else {
            return
        }

        captureSession.startRunning()
        DispatchQueue.main.async {
            self.isRunning = true
        }
    }

    private func publishCameraControlSupport(
        isAvailable: Bool,
        exposureRange: ClosedRange<Float> = -2...2,
        zoomRange: ClosedRange<CGFloat> = 1...1
    ) {
        DispatchQueue.main.async {
            self.cameraControlsAvailable = isAvailable
            self.supportedExposureRange = exposureRange
            self.supportedZoomRange = zoomRange
        }
    }

    private func publishCameraControlResult(
        success: Bool,
        message: String,
        completion: CameraControlCompletion?
    ) {
        DispatchQueue.main.async {
            if !success {
                self.latestError = message
            }

            completion?(success, message)
        }
    }

    private func publishError(_ message: String) {
        DispatchQueue.main.async {
            self.latestError = message
        }
    }
}

extension CameraSessionController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        frameConsumer?.cameraSession(self, didOutput: sampleBuffer)
    }
}

