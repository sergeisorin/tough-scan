import SwiftUI
import ToughScanCore

struct RecognizedTextPanel: View {
    let blocks: [RecognizedTextBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recovered text")
                .font(.headline)

            if blocks.isEmpty {
                Text("No text has enough evidence yet. Return to scanning and hold steady over missing regions.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    let style = ConfidenceStateStyle.style(
                        for: ScanConfidenceState.state(for: block.confidence)
                    )
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(Int(block.confidence * 100))%")
                                .font(.caption.monospacedDigit())
                            Text(style.title)
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(style.color)
                        .frame(width: 62, alignment: .trailing)

                        Text(block.text)
                            .font(.body)
                            .textSelection(.enabled)
                            .multilineTextAlignment(block.languageCode.contains("he") ? .trailing : .leading)
                            .frame(maxWidth: .infinity, alignment: block.languageCode.contains("he") ? .trailing : .leading)
                    }
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }
}
