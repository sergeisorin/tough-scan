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
        .background(StartScreenColors.background.ignoresSafeArea())
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

            ZStack {
                StartScreenColors.background
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: layout.verticalSpacing) {
                    if layout.showsWordmark {
                        AppWordmark()
                    }

                    Spacer(minLength: layout.topSpacer)

                    StartDocumentHero(layout: layout)
                        .frame(maxWidth: .infinity)
                        .frame(height: layout.heroHeight)

                    VStack(alignment: .leading, spacing: layout.titleBodySpacing) {
                        Text("Recover difficult text")
                            .font(.system(size: layout.titleFontSize, weight: .bold, design: .default))
                            .tracking(-0.7)
                            .foregroundStyle(StartScreenColors.title)
                            .lineLimit(1)
                            .minimumScaleFactor(0.88)

                        Text("Progressively scan faded Hebrew and English documents. Processing stays on this iPhone.")
                            .font(.system(size: layout.bodyFontSize, weight: .regular))
                            .lineSpacing(3)
                            .foregroundStyle(StartScreenColors.body)
                            .lineLimit(3)
                            .minimumScaleFactor(0.90)
                    }

                    VStack(spacing: 0) {
                        LocalPromiseRow(
                            symbolName: "lock",
                            title: "No server or cloud OCR",
                            subtitle: "Capture, OCR and reconstruction happen on this device.",
                            layout: layout
                        )
                        Divider()
                        LocalPromiseRow(
                            symbolName: "square.grid.2x2",
                            title: "Confidence by region and text",
                            subtitle: "You see exactly which words the model is unsure about.",
                            layout: layout
                        )
                        Divider()
                        LocalPromiseRow(
                            symbolName: "arrow.clockwise",
                            title: "Guided rescans for weak areas",
                            subtitle: "The app tells you where to look again, never just retakes blindly.",
                            layout: layout
                        )
                    }
                    .background(StartScreenColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 16, y: 10)

                    Spacer(minLength: layout.bottomSpacer)

                    Button(action: onStart) {
                        Label("Start local scan", systemImage: "viewfinder")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: layout.buttonHeight)
                    }
                    .buttonStyle(StartScanPrimaryButtonStyle())

                    HStack(spacing: 6) {
                        Image(systemName: "shield")
                        Text("Nothing leaves this device. No account required.")
                    }
                    .font(.system(size: layout.privacyFontSize, weight: .medium))
                    .foregroundStyle(StartScreenColors.caption)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, layout.horizontalPadding)
                .padding(.top, max(layout.verticalPadding, geometry.safeAreaInsets.top + 8))
                .padding(.bottom, max(layout.verticalPadding, geometry.safeAreaInsets.bottom + 8))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .ignoresSafeArea(.container, edges: .all)
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
    static let buttonTitle = Color(red: 0.97, green: 1.00, blue: 0.99)
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
    let layout: StartScreenLayout

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
                .frame(height: layout.heroHeight)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white)
                .frame(width: 184, height: 142)
                .shadow(color: .black.opacity(0.10), radius: 22, y: 12)
                .rotationEffect(.degrees(-4))
                .scaleEffect(layout.documentScale)
                .overlay {
                    StartDocumentHeroLines()
                        .rotationEffect(.degrees(-4))
                        .scaleEffect(layout.documentScale)
                }
        }
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
    let layout: StartScreenLayout

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(StartScreenColors.iconForeground)
                .frame(width: layout.promiseIconSize, height: layout.promiseIconSize)
                .background(StartScreenColors.iconBackground)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: layout.promiseTitleFontSize, weight: .semibold))
                    .foregroundStyle(StartScreenColors.cardTitle)
                    .lineLimit(2)
                    .minimumScaleFactor(0.88)
                Text(subtitle)
                    .font(.system(size: layout.promiseSubtitleFontSize, weight: .regular))
                    .foregroundStyle(StartScreenColors.cardSubtitle)
                    .lineLimit(2)
                    .minimumScaleFactor(0.88)
            }

            Spacer()
        }
        .padding(.horizontal, layout.promiseRowHorizontalPadding)
        .padding(.vertical, layout.promiseRowVerticalPadding)
    }
}

private struct StartScanPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(StartScreenColors.buttonTitle)
            .background(StartScreenColors.accent)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

