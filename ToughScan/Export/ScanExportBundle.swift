import Foundation

struct ScanExportBundle: Identifiable {
    let id = UUID()
    let directoryURL: URL
    let fileURLs: [URL]

    func cleanup() {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}

