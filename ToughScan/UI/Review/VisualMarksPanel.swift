import SwiftUI

struct VisualMarksPanel: View {
    let regions: [VisualDocumentRegion]
    let message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Visual marks")
                .font(.headline)

            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if regions.isEmpty {
                Text("No stamps, signatures, or non-text marks detected.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(regions.count) likely non-text mark\(regions.count == 1 ? "" : "s") will be preserved for recomposed export.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(regions) { region in
                            Image(uiImage: region.image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 82, height: 82)
                                .padding(6)
                                .background(Color(uiColor: .tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .accessibilityLabel("Detected visual mark")
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
