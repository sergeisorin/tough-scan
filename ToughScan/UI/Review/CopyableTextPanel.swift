import SwiftUI

struct CopyableTextPanel: View {
    let summary: ReviewTextSourceSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Copyable recovered text")
                .font(.headline)

            if summary.isEmpty {
                Text("No copyable text is ready yet. Rescan weak areas or add another page to improve OCR before copying.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Ready to copy \(summary.sourceDescription) from \(summary.copyablePageDescription). This is the same recovered source used for text export and AI-assisted review.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
