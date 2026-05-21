public struct ScanGuidance: Equatable, Sendable {
    public enum Action: Equatable, Sendable {
        case scanMissingRegion
        case rescanWeakText
        case holdSteady
        case readyForReview
    }

    public let action: Action
    public let targetTile: ScanTile?
    public let readyForReview: Bool

    public init(
        action: Action,
        targetTile: ScanTile?,
        readyForReview: Bool
    ) {
        self.action = action
        self.targetTile = targetTile
        self.readyForReview = readyForReview
    }
}

