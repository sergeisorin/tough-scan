import CoreGraphics
import Foundation
import ToughScanCore

enum ScanAutomationCommand: Equatable {
    case none
    case enableTorch
    case disableTorch
    case setExposureBias(Float)
    case focusAt(CGPoint)
    case setZoom(CGFloat)
    case showGuidance(String)
}

struct ScanAutomationDecision: Equatable {
    let command: ScanAutomationCommand
    let message: String?

    static let none = ScanAutomationDecision(command: .none, message: nil)
}

struct ScanAutomationController {
    private let gridWidth: Int
    private let gridHeight: Int
    private let commandCooldown: TimeInterval
    private var lastCommandTime: Date?

    init(
        gridWidth: Int = 4,
        gridHeight: Int = 6,
        commandCooldown: TimeInterval = 2.5
    ) {
        self.gridWidth = gridWidth
        self.gridHeight = gridHeight
        self.commandCooldown = commandCooldown
    }

    mutating func nextDecision(
        metrics: FrameQualityMetrics,
        guidance: ScanGuidance,
        cameraState: CameraControlState,
        now: Date = Date()
    ) -> ScanAutomationDecision {
        guard canIssueCommand(at: now) else {
            return .none
        }

        let decision: ScanAutomationDecision

        if metrics.isLikelySmudged, metrics.geometryConfidence > 0.65 {
            decision = ScanAutomationDecision(
                command: .showGuidance("Camera lens may be smudged. Clean the lens and try another pass."),
                message: "Camera lens may be smudged. Clean the lens and try another pass."
            )
        } else if metrics.sharpness < 0.18, metrics.geometryConfidence > 0.65 {
            decision = ScanAutomationDecision(
                command: .showGuidance("Hold still so the text sharpens."),
                message: "Hold still so the text sharpens."
            )
        } else if metrics.glareRisk > 0.25 {
            decision = glareDecision(cameraState: cameraState)
        } else if metrics.brightness < 0.30 {
            decision = lowLightDecision(cameraState: cameraState)
        } else if shouldZoomForSmallText(metrics: metrics, guidance: guidance, cameraState: cameraState) {
            decision = ScanAutomationDecision(
                command: .setZoom(min(cameraState.zoomFactor + 0.25, cameraState.supportedZoomRange.upperBound)),
                message: "Zooming in for small text."
            )
        } else if let targetTile = guidance.targetTile {
            decision = ScanAutomationDecision(
                command: .focusAt(focusPoint(for: targetTile.coordinate)),
                message: "Focusing the weak region."
            )
        } else {
            decision = .none
        }

        if decision.command != .none {
            lastCommandTime = now
        }

        return decision
    }

    private func canIssueCommand(at now: Date) -> Bool {
        guard let lastCommandTime else {
            return true
        }

        return now.timeIntervalSince(lastCommandTime) >= commandCooldown
    }

    private func lowLightDecision(cameraState: CameraControlState) -> ScanAutomationDecision {
        if !cameraState.torchEnabled {
            return ScanAutomationDecision(
                command: .enableTorch,
                message: "Adding light for low-contrast text."
            )
        }

        return ScanAutomationDecision(
            command: .setExposureBias(cameraState.exposureBias + 0.25),
            message: "Brightening the text slightly."
        )
    }

    private func glareDecision(cameraState: CameraControlState) -> ScanAutomationDecision {
        if cameraState.torchEnabled {
            return ScanAutomationDecision(
                command: .disableTorch,
                message: "Reducing glare from the page."
            )
        }

        return ScanAutomationDecision(
            command: .setExposureBias(cameraState.exposureBias - 0.25),
            message: "Reducing glare from the page."
        )
    }

    private func shouldZoomForSmallText(
        metrics: FrameQualityMetrics,
        guidance: ScanGuidance,
        cameraState: CameraControlState
    ) -> Bool {
        guidance.targetTile != nil &&
            metrics.documentCoverage < 0.35 &&
            metrics.sharpness >= 0.35 &&
            metrics.geometryConfidence >= 0.65 &&
            cameraState.zoomFactor < cameraState.supportedZoomRange.upperBound
    }

    private func focusPoint(for coordinate: TileCoordinate) -> CGPoint {
        let x = (CGFloat(coordinate.column) + 0.5) / CGFloat(max(gridWidth, 1))
        let y = (CGFloat(coordinate.row) + 0.5) / CGFloat(max(gridHeight, 1))

        return CGPoint(
            x: min(max(x, 0), 1),
            y: min(max(y, 0), 1)
        )
    }
}
