import Foundation

struct CameraControlState: Equatable {
    private static let neutralExposureBias: Float = 0
    private static let neutralExposureTolerance: Float = 0.05

    var torchEnabled: Bool
    private(set) var exposureBias: Float
    let supportedExposureRange: ClosedRange<Float>

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
        supportedExposureRange: ClosedRange<Float> = -2...2
    ) {
        self.torchEnabled = torchEnabled
        self.supportedExposureRange = supportedExposureRange
        self.exposureBias = exposureBias.clamped(to: supportedExposureRange)
    }

    mutating func setExposureBias(_ value: Float) {
        exposureBias = value.clamped(to: supportedExposureRange)
    }

    mutating func reset() {
        torchEnabled = false
        exposureBias = Self.neutralExposureBias.clamped(to: supportedExposureRange)
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

