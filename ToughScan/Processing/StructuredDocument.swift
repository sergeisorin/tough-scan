import Foundation

struct StructuredDocument: Equatable {
    let paragraphs: [String]
    let tables: [StructuredTable]
    let lists: [StructuredList]
    let barcodes: [String]

    var exportText: String {
        var sections: [String] = []

        if !paragraphs.isEmpty {
            sections.append(paragraphs.joined(separator: "\n"))
        }

        sections.append(contentsOf: lists.map(\.exportText))
        sections.append(contentsOf: tables.map(\.tsvText))

        if !barcodes.isEmpty {
            sections.append("Barcodes\n" + barcodes.joined(separator: "\n"))
        }

        return sections
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
    }
}

struct StructuredTable: Equatable {
    let rows: [[String]]

    var tsvText: String {
        rows
            .map { row in row.joined(separator: "\t") }
            .joined(separator: "\n")
    }
}

struct StructuredList: Equatable {
    let items: [String]

    var exportText: String {
        items
            .map { "- \($0)" }
            .joined(separator: "\n")
    }
}
