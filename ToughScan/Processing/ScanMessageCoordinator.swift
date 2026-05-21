import Foundation

enum ScanMessagePriority: Int, Comparable {
    case guidance = 0
    case automation = 1
    case qualityWarning = 2
    case error = 3

    static func < (lhs: ScanMessagePriority, rhs: ScanMessagePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct ScanMessageCoordinator {
    private(set) var currentMessage: String?
    private var currentPriority: ScanMessagePriority?

    mutating func submit(_ message: String, priority: ScanMessagePriority) {
        guard let existingPriority = currentPriority else {
            currentMessage = message
            currentPriority = priority
            return
        }

        guard priority >= existingPriority else {
            return
        }

        currentMessage = message
        currentPriority = priority
    }
}
