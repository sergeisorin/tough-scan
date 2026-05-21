import AVFoundation
import Combine
import Foundation

protocol CameraFrameConsumer: AnyObject {
    func cameraSession(_ session: CameraSessionController, didOutput sampleBuffer: CMSampleBuffer)
}

final class CameraSessionController: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: AVAuthorizationStatus
    @Published private(set) var isRunning = false
    @Published private(set) var latestError: String?

    let captureSession = AVCaptureSession()

    weak var frameConsumer: CameraFrameConsumer?

    private let sessionQueue = DispatchQueue(label: "com.local.toughscan.camera-session")
    private let videoOutput = AVCaptureVideoDataOutput()

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

    func configure() {
        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }

            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .photo
            defer {
                self.captureSession.commitConfiguration()
            }

            self.captureSession.inputs.forEach(self.captureSession.removeInput)
            self.captureSession.outputs.forEach(self.captureSession.removeOutput)

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.captureSession.canAddInput(input) else {
                self.publishError("Back camera is not available.")
                return
            }

            self.captureSession.addInput(input)

            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            self.videoOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)

            guard self.captureSession.canAddOutput(self.videoOutput) else {
                self.publishError("Camera frame output is not available.")
                return
            }

            self.captureSession.addOutput(self.videoOutput)
            self.videoOutput.connection(with: .video)?.videoRotationAngle = 90
        }
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self, !self.captureSession.isRunning else {
                return
            }

            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.isRunning = true
            }
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

    func setTorch(enabled: Bool) {
        sessionQueue.async { [weak self] in
            guard let device = (self?.captureSession.inputs.first as? AVCaptureDeviceInput)?.device,
                  device.hasTorch else {
                return
            }

            do {
                try device.lockForConfiguration()
                device.torchMode = enabled ? .on : .off
                device.unlockForConfiguration()
            } catch {
                self?.publishError("Torch could not be changed.")
            }
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

