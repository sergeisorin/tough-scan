import SwiftUI

struct StructuredDocumentPanel: View {
    let document: StructuredDocument?
    let message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Document structure")
                .font(.headline)

            if let document {
                if document.exportText.isEmpty {
                    Text("No structured paragraphs, tables, lists, or barcodes were detected.")
                        .foregroundStyle(.secondary)
                } else {
                    if !document.paragraphs.isEmpty {
                        Text("\(document.paragraphs.count) paragraph groups detected")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(Array(document.tables.enumerated()), id: \.offset) { index, table in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Table \(index + 1)")
                                .font(.subheadline.weight(.semibold))
                            Text(table.tsvText)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                    }

                    if !document.lists.isEmpty {
                        Text("\(document.lists.count) lists detected")
                            .foregroundStyle(.secondary)
                    }

                    if !document.barcodes.isEmpty {
                        Text("Barcodes: \(document.barcodes.joined(separator: ", "))")
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                }
            } else {
                Text(message ?? "Document structure will appear after the page is analyzed.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
