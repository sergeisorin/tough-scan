public struct ScanGuidance: Equatable, Sendable {
    public enum Action: Equatable, Sendable {
        case scanMissingRegion
        case rescanWeakText
        case holdSteady
        case readyForReview
    }

    public let action: Action
    public let targetTile: ScanTile?
    public let targetWord: RecognizedWord?
    public let readyForReview: Bool

    public init(
        action: Action,
        targetTile: ScanTile?,
        targetWord: RecognizedWord? = nil,
        readyForReview: Bool
    ) {
        self.action = action
        self.targetTile = targetTile
        self.targetWord = targetWord
        self.readyForReview = readyForReview
    }
}

