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
                    HStack(spacing: 8) {
                        Image(systemName: style.symbolName)
                            .foregroundStyle(style.color)
                        Text(style.title)
                            .font(.subheadline.weight(.medium))
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
}
