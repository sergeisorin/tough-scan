import SwiftUI

struct PageSetPanel: View {
    let pageSet: ReviewPageSet
    let onRemoveCapturedPage: (ScannedPage.ID) -> Void

    @State private var pagePendingRemoval: ReviewPageSet.DisplayPage?
    @State private var isConfirmingPageRemoval = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Pages ready: \(pageSet.pagesForExport.count)")
                    .font(.headline)
                Text("Only the pages listed here will be included in the local PDF and text export.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if pageSet.displayPages.isEmpty {
                Text("No pages are ready for export yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(pageSet.displayPages) { displayPage in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayPage.title)
                                .font(.subheadline.weight(.semibold))
                            Text(summary(for: displayPage))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if displayPage.canDelete {
                            Button(role: .destructive) {
                                pagePendingRemoval = displayPage
                                isConfirmingPageRemoval = true
                            } label: {
                                Label("Remove", systemImage: "trash")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.borderless)
                            .frame(width: 44, height: 44)
                            .accessibilityLabel("Remove \(displayPage.title)")
                        } else {
                            Text("Included")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .confirmationDialog(
            "Remove page?",
            isPresented: $isConfirmingPageRemoval,
            titleVisibility: .visible
        ) {
            if let pagePendingRemoval {
                Button("Remove \(pagePendingRemoval.title)", role: .destructive) {
                    onRemoveCapturedPage(pagePendingRemoval.id)
                    self.pagePendingRemoval = nil
                }
            }
        } message: {
            if let pagePendingRemoval {
                Text("\(pagePendingRemoval.title) will be removed from this export set.")
            }
        }
    }

    private func summary(for displayPage: ReviewPageSet.DisplayPage) -> String {
        let visualQuality = Int(displayPage.visualQuality * 100)
        let lineLabel = displayPage.textLineCount == 1 ? "text line" : "text lines"
        let markLabel = displayPage.visualRegionCount == 1 ? "visual mark" : "visual marks"
        return "\(visualQuality)% visual quality · \(displayPage.textLineCount) \(lineLabel) · \(displayPage.visualRegionCount) \(markLabel)"
    }
}
