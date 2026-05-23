import SwiftUI
import ToughScanCore

struct RootView: View {
    @State private var route: Route = .start
    @State private var session = ProgressiveScanSession(gridWidth: 4, gridHeight: 6)
    @State private var bestSnapshot: DocumentSnapshot?
    @State private var capturedPages: [ScannedPage] = []
    @State private var preferredRescanWord: RecognizedWord?
    @State private var pendingConfirmedWords: [ConfirmedRecognizedWord] = []

    var body: some View {
        NavigationStack {
            switch route {
            case .start:
                StartScanView {
                    preferredRescanWord = nil
                    pendingConfirmedWords = []
                    route = .scan
                }
            case .scan:
                LiveScanView(
                    session: $session,
                    bestSnapshot: $bestSnapshot,
                    preferredTargetWord: preferredRescanWord
                ) {
                    preferredRescanWord = nil
                    route = .review
                }
            case .review:
                ScanReviewView(
                    session: session,
                    snapshot: bestSnapshot,
                    capturedPages: capturedPages,
                    initialConfirmedWords: pendingConfirmedWords,
                    onAddPage: addCurrentPageAndContinue,
                    onRemoveCapturedPage: removeCapturedPage,
                    onRescan: beginRescan
                )
            }
        }
    }

    private func beginRescan(targetWord: RecognizedWord?, confirmedWords: [ConfirmedRecognizedWord]) {
        preferredRescanWord = targetWord
        pendingConfirmedWords = confirmedWords
        route = .scan
    }

    private func addCurrentPageAndContinue(
        structuredDocument: StructuredDocument?,
        visualRegions: [VisualDocumentRegion],
        confirmedWords: [ConfirmedRecognizedWord]
    ) {
        guard let bestSnapshot else {
            return
        }

        capturedPages.append(
            ScannedPage(
                snapshot: bestSnapshot,
                recognizedTextBlocks: session.recognizedTextBlocks,
                recognizedWords: session.recognizedWords,
                confirmedWords: confirmedWords,
                structuredDocument: structuredDocument,
                visualRegions: visualRegions
            )
        )
        session = ProgressiveScanSession(gridWidth: 4, gridHeight: 6)
        self.bestSnapshot = nil
        preferredRescanWord = nil
        pendingConfirmedWords = []
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
        GeometryReader { geometry in
            let layout = StartScreenLayout.metrics(forAvailableHeight: geometry.size.height)

            ScrollView {
                VStack(alignment: .leading, spacing: layout.verticalSpacing) {
                    if !layout.isCompact {
                        AppWordmark()
                            .padding(.top, 4)
                    }

                    Spacer(minLength: layout.topSpacer)

                    StartDocumentHero(isCompact: layout.isCompact)
                        .frame(maxWidth: .infinity)
                        .frame(height: layout.heroHeight)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recover difficult text")
                            .font(.system(size: layout.titleFontSize, weight: .bold, design: .default))
                            .tracking(-0.7)
                            .foregroundStyle(StartScreenColors.title)

                        Text("Progressively scan faded Hebrew and English documents. Processing stays on this iPhone.")
                            .font(.subheadline)
                            .lineSpacing(3)
                            .foregroundStyle(StartScreenColors.body)
                    }

                    VStack(spacing: 1) {
                        LocalPromiseRow(
                            symbolName: "lock",
                            title: "No server or cloud OCR",
                            subtitle: "Capture, OCR and reconstruction happen on this device."
                        )
                        LocalPromiseRow(
                            symbolName: "square.grid.2x2",
                            title: "Confidence shown by region and text",
                            subtitle: "You see exactly which words the model is unsure about."
                        )
                        LocalPromiseRow(
                            symbolName: "arrow.clockwise",
                            title: "Guided rescans for weak areas",
                            subtitle: "The app tells you where to look again, never just retakes blindly."
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 20, y: 14)

                    Spacer(minLength: layout.bottomSpacer)

                    Button(action: onStart) {
                        Label("Start local scan", systemImage: "viewfinder")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(StartScreenColors.accent)

                    HStack(spacing: 6) {
                        Image(systemName: "shield")
                        Text("Nothing leaves this device. No account required.")
                    }
                    .font(.caption2)
                    .foregroundStyle(StartScreenColors.caption)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, layout.horizontalPadding)
                .padding(.vertical, layout.verticalPadding)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .top)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(StartScreenColors.background.ignoresSafeArea())
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }
}

private enum StartScreenColors {
    static let background = Color(red: 0.06, green: 0.09, blue: 0.15)
    static let accent = Color(red: 0.36, green: 0.79, blue: 0.63)
    static let title = Color.white
    static let body = Color.white.opacity(0.76)
    static let caption = Color.white.opacity(0.62)
    static let wordmark = Color.white.opacity(0.70)
    static let wordmarkSecondary = Color.white.opacity(0.50)
    static let card = Color.white.opacity(0.96)
    static let cardTitle = Color(red: 0.10, green: 0.13, blue: 0.20)
    static let cardSubtitle = Color(red: 0.42, green: 0.45, blue: 0.54)
    static let iconBackground = Color(red: 0.91, green: 0.94, blue: 0.98)
    static let iconForeground = Color(red: 0.16, green: 0.29, blue: 0.56)
    static let heroInk = Color(red: 0.16, green: 0.22, blue: 0.35)
}

private struct AppWordmark: View {
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(red: 0.16, green: 0.29, blue: 0.56))
                Image(systemName: "viewfinder")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 26, height: 26)

            Text("TOUGH SCAN")
                .font(.caption.weight(.bold))
                .tracking(2.2)
                .foregroundStyle(StartScreenColors.wordmark)

            Spacer()

            Text("v1.0 · local")
                .font(.caption2.monospaced())
                .foregroundStyle(StartScreenColors.wordmarkSecondary)
                .textCase(.uppercase)
        }
    }
}

private struct StartDocumentHero: View {
    let isCompact: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.16, green: 0.29, blue: 0.56).opacity(0.13),
                            .clear
                        ],
                        center: .center,
                        startRadius: 6,
                        endRadius: 110
                    )
                )
                .frame(height: 170)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white)
                .frame(width: 184, height: 142)
                .shadow(color: .black.opacity(0.10), radius: 22, y: 12)
                .rotationEffect(.degrees(-4))
                .overlay {
                    StartDocumentHeroLines()
                        .rotationEffect(.degrees(-4))
                }
        }
        .scaleEffect(isCompact ? 0.78 : 1)
    }
}

private struct StartDocumentHeroLines: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Capsule().fill(StartScreenColors.heroInk.opacity(0.55)).frame(width: 60, height: 5)
            Capsule().fill(StartScreenColors.heroInk.opacity(0.24)).frame(width: 130, height: 3)
            Capsule().fill(StartScreenColors.heroInk.opacity(0.18)).frame(width: 150, height: 3)
            Capsule().fill(.green.opacity(0.25)).frame(width: 82, height: 12)
            Capsule().fill(StartScreenColors.heroInk.opacity(0.34)).frame(width: 150, height: 3)
            Capsule().fill(.orange.opacity(0.25)).frame(width: 92, height: 12)
            Capsule().fill(.red.opacity(0.22)).frame(width: 118, height: 12)
        }
        .padding(18)
        .frame(width: 184, height: 142, alignment: .topLeading)
    }
}

private struct LocalPromiseRow: View {
    let symbolName: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(StartScreenColors.iconForeground)
                .frame(width: 32, height: 32)
                .background(StartScreenColors.iconBackground)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(StartScreenColors.cardTitle)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(StartScreenColors.cardSubtitle)
            }

            Spacer()
        }
        .padding(14)
        .background(StartScreenColors.card)
    }
}

