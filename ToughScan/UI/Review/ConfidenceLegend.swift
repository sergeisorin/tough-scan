import SwiftUI
import ToughScanCore

struct ConfidenceLegend: View {
    private let states: [ScanConfidenceState] = [
        .successful,
        .uncertain,
        .veryUncertain,
        .needsScan
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Confidence legend")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 138), spacing: 10)], spacing: 10) {
                ForEach(states, id: \.self) { state in
                    let style = ConfidenceStateStyle.style(for: state)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: style.symbolName)
                                .foregroundStyle(style.color)
                            Text(style.title)
                                .font(.subheadline.weight(.medium))
                        }

                        Text(description(for: state))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(style.color.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel(style.title)
                }
            }
        }
    }

    private func description(for state: ScanConfidenceState) -> String {
        switch state {
        case .successful:
            return "Good enough for review."
        case .uncertain:
            return "Optional rescan if this text matters."
        case .veryUncertain:
            return "Scan this region again."
        case .needsScan:
            return "Not scanned yet."
        }
    }
}
