import AVFoundation
import SwiftUI
import UIKit

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    var onTapDevicePoint: ((CGPoint) -> Void)? = nil
    var automationFocusRequest: CameraFocusRequest? = nil

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill

        let tapRecognizer = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        view.addGestureRecognizer(tapRecognizer)
        context.coordinator.previewView = view

        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
        context.coordinator.onTapDevicePoint = onTapDevicePoint
        context.coordinator.previewView = uiView
        context.coordinator.handleAutomationFocusRequest(automationFocusRequest)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTapDevicePoint: onTapDevicePoint)
    }

    final class Coordinator: NSObject {
        var onTapDevicePoint: ((CGPoint) -> Void)?
        weak var previewView: PreviewView?
        private var handledAutomationFocusRequestID: UUID?

        init(onTapDevicePoint: ((CGPoint) -> Void)?) {
            self.onTapDevicePoint = onTapDevicePoint
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let previewView else {
                return
            }

            let layerPoint = recognizer.location(in: previewView)
            let devicePoint = previewView.videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: layerPoint)
            onTapDevicePoint?(devicePoint)
        }

        func handleAutomationFocusRequest(_ request: CameraFocusRequest?) {
            guard let request,
                  handledAutomationFocusRequestID != request.id,
                  let previewView,
                  previewView.bounds.width > 0,
                  previewView.bounds.height > 0 else {
                return
            }

            let layerPoint = CGPoint(
                x: request.normalizedPreviewPoint.x * previewView.bounds.width,
                y: request.normalizedPreviewPoint.y * previewView.bounds.height
            )
            let devicePoint = previewView.videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: layerPoint)

            handledAutomationFocusRequestID = request.id
            onTapDevicePoint?(devicePoint)
        }
    }
}

struct CameraFocusRequest: Equatable {
    let id: UUID
    let normalizedPreviewPoint: CGPoint

    init(
        id: UUID = UUID(),
        normalizedPreviewPoint: CGPoint
    ) {
        self.id = id
        self.normalizedPreviewPoint = CGPoint(
            x: min(max(normalizedPreviewPoint.x, 0), 1),
            y: min(max(normalizedPreviewPoint.y, 0), 1)
        )
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

