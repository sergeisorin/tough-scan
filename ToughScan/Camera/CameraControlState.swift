import CoreGraphics
import Foundation

struct CameraControlState: Equatable {
    private static let neutralExposureBias: Float = 0
    private static let neutralExposureTolerance: Float = 0.05

    var torchEnabled: Bool
    private(set) var exposureBias: Float
    let supportedExposureRange: ClosedRange<Float>
    private(set) var zoomFactor: CGFloat
    let supportedZoomRange: ClosedRange<CGFloat>

    var exposureLabel: String {
        if exposureBias < -Self.neutralExposureTolerance {
            return "Darker"
        }

        if exposureBias > Self.neutralExposureTolerance {
            return "Brighter"
        }

        return "Neutral"
    }

    init(
        torchEnabled: Bool = false,
        exposureBias: Float = Self.neutralExposureBias,
        supportedExposureRange: ClosedRange<Float> = -2...2,
        zoomFactor: CGFloat = 1,
        supportedZoomRange: ClosedRange<CGFloat> = 1...1
    ) {
        self.torchEnabled = torchEnabled
        self.supportedExposureRange = supportedExposureRange
        self.exposureBias = exposureBias.clamped(to: supportedExposureRange)
        self.supportedZoomRange = supportedZoomRange
        self.zoomFactor = zoomFactor.clamped(to: supportedZoomRange)
    }

    mutating func setExposureBias(_ value: Float) {
        exposureBias = value.clamped(to: supportedExposureRange)
    }

    mutating func setZoomFactor(_ value: CGFloat) {
        zoomFactor = value.clamped(to: supportedZoomRange)
    }

    mutating func reset() {
        torchEnabled = false
        exposureBias = Self.neutralExposureBias.clamped(to: supportedExposureRange)
        zoomFactor = CGFloat(1).clamped(to: supportedZoomRange)
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

