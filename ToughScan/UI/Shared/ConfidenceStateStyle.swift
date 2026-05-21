import SwiftUI
import ToughScanCore

struct ConfidenceStateStyle: Equatable {
    let title: String
    let symbolName: String
    let color: Color
    let pattern: String

    static func style(for state: ScanConfidenceState) -> ConfidenceStateStyle {
        switch state {
        case .successful:
            return ConfidenceStateStyle(
                title: "Successful",
                symbolName: "checkmark.circle.fill",
                color: Color(red: 0.14, green: 0.52, blue: 0.34),
                pattern: "solid"
            )
        case .uncertain:
            return ConfidenceStateStyle(
                title: "Review",
                symbolName: "questionmark.circle",
                color: Color(red: 0.82, green: 0.56, blue: 0.18),
                pattern: "soft"
            )
        case .veryUncertain:
            return ConfidenceStateStyle(
                title: "Rescan",
                symbolName: "exclamationmark.triangle",
                color: Color(red: 0.78, green: 0.30, blue: 0.20),
                pattern: "dense"
            )
        case .needsScan:
            return ConfidenceStateStyle(
                title: "Needed",
                symbolName: "viewfinder",
                color: Color(red: 0.36, green: 0.39, blue: 0.44),
                pattern: "empty"
            )
        }
    }
}

