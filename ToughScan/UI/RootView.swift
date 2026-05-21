import SwiftUI
import ToughScanCore

struct RootView: View {
    @State private var route: Route = .start
    @State private var session = ProgressiveScanSession(gridWidth: 4, gridHeight: 6)
    @State private var bestSnapshot: DocumentSnapshot?
    @State private var capturedPages: [ScannedPage] = []

    var body: some View {
        NavigationStack {
            switch route {
            case .start:
                StartScanView {
                    route = .scan
                }
            case .scan:
                LiveScanView(
                    session: $session,
                    bestSnapshot: $bestSnapshot
                ) {
                    route = .review
                }
            case .review:
                ScanReviewView(
                    session: session,
                    snapshot: bestSnapshot,
                    capturedPages: capturedPages,
                    onAddPage: addCurrentPageAndContinue,
                    onRemoveCapturedPage: removeCapturedPage
                ) {
                    route = .scan
                }
            }
        }
    }

    private func addCurrentPageAndContinue() {
        guard let bestSnapshot else {
            return
        }

        capturedPages.append(
            ScannedPage(
                snapshot: bestSnapshot,
                recognizedTextBlocks: session.recognizedTextBlocks
            )
        )
        session = ProgressiveScanSession(gridWidth: 4, gridHeight: 6)
        self.bestSnapshot = nil
        route = .scan
    }

    private func removeCapturedPage(id: ScannedPage.ID) {
        capturedPages.removeAll { $0.id == id }
    }
}

private enum Route {
    case start
    case scan
    case review
}

private struct StartScanView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                Text("Recover difficult text")
                    .font(.system(.largeTitle, design: .serif, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Progressively scan faded Hebrew and English documents. Processing stays on this iPhone.")
                    .font(.body)
                    .lineSpacing(3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                LocalPromiseRow(text: "No server or cloud OCR")
                LocalPromiseRow(text: "Confidence shown by region and text")
                LocalPromiseRow(text: "Guided rescans for weak areas")
            }

            Button(action: onStart) {
                Text("Start local scan")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding(24)
        .navigationTitle("Tough Scan")
    }
}

private struct LocalPromiseRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal")
                .foregroundStyle(.green)
            Text(text)
                .foregroundStyle(.primary)
        }
        .font(.callout)
    }
}

