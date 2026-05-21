public enum ScanConfidenceState: Int, Comparable, Sendable {
    case needsScan = 0
    case veryUncertain = 1
    case uncertain = 2
    case successful = 3

    public static func < (lhs: ScanConfidenceState, rhs: ScanConfidenceState) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public static func state(for combinedConfidence: Double) -> ScanConfidenceState {
        switch combinedConfidence {
        case ..<0.01:
            return .needsScan
        case ..<0.45:
            return .veryUncertain
        case ..<0.70:
            return .uncertain
        default:
            return .successful
        }
    }
}

