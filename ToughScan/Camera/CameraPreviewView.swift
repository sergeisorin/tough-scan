import AVFoundation
import SwiftUI
import UIKit

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    var onTapDevicePoint: ((CGPoint) -> Void)? = nil

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
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTapDevicePoint: onTapDevicePoint)
    }

    final class Coordinator: NSObject {
        var onTapDevicePoint: ((CGPoint) -> Void)?
        weak var previewView: PreviewView?

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

