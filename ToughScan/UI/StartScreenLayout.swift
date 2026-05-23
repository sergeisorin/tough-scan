import CoreGraphics

struct StartScreenLayout: Equatable {
    let isCompact: Bool
    let showsWordmark: Bool
    let heroHeight: CGFloat
    let documentScale: CGFloat
    let verticalSpacing: CGFloat
    let titleBodySpacing: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let topSpacer: CGFloat
    let bottomSpacer: CGFloat
    let titleFontSize: CGFloat
    let bodyFontSize: CGFloat
    let promiseRowVerticalPadding: CGFloat
    let promiseRowHorizontalPadding: CGFloat
    let promiseIconSize: CGFloat
    let promiseTitleFontSize: CGFloat
    let promiseSubtitleFontSize: CGFloat
    let buttonHeight: CGFloat
    let privacySpacing: CGFloat
    let privacyFontSize: CGFloat

    var usesScrolling: Bool {
        false
    }

    var estimatedContentHeight: CGFloat {
        let wordmarkHeight: CGFloat = showsWordmark ? 26 + verticalSpacing : 0
        let titleBlockHeight = titleFontSize * 1.18 + titleBodySpacing + bodyFontSize * 3.2
        let rowTextHeight = promiseTitleFontSize * 2.35 + promiseSubtitleFontSize * 2.35
        let rowHeight = max(promiseIconSize, rowTextHeight) + promiseRowVerticalPadding * 2
        let promisePanelHeight = rowHeight * 3 + 2
        let privacyHeight = privacyFontSize * 1.4

        return verticalPadding * 2
            + wordmarkHeight
            + topSpacer
            + heroHeight
            + verticalSpacing
            + titleBlockHeight
            + verticalSpacing
            + promisePanelHeight
            + verticalSpacing
            + bottomSpacer
            + buttonHeight
            + privacySpacing
            + privacyHeight
    }

    static let compressed = StartScreenLayout(
        isCompact: true,
        showsWordmark: false,
        heroHeight: 96,
        documentScale: 0.70,
        verticalSpacing: 10,
        titleBodySpacing: 8,
        horizontalPadding: 24,
        verticalPadding: 14,
        topSpacer: 0,
        bottomSpacer: 4,
        titleFontSize: 29,
        bodyFontSize: 15,
        promiseRowVerticalPadding: 7,
        promiseRowHorizontalPadding: 14,
        promiseIconSize: 30,
        promiseTitleFontSize: 16,
        promiseSubtitleFontSize: 12,
        buttonHeight: 56,
        privacySpacing: 10,
        privacyFontSize: 11
    )

    static let compact = StartScreenLayout(
        isCompact: true,
        showsWordmark: false,
        heroHeight: 112,
        documentScale: 0.78,
        verticalSpacing: 12,
        titleBodySpacing: 8,
        horizontalPadding: 24,
        verticalPadding: 18,
        topSpacer: 0,
        bottomSpacer: 6,
        titleFontSize: 30,
        bodyFontSize: 15,
        promiseRowVerticalPadding: 9,
        promiseRowHorizontalPadding: 14,
        promiseIconSize: 32,
        promiseTitleFontSize: 16,
        promiseSubtitleFontSize: 12,
        buttonHeight: 56,
        privacySpacing: 10,
        privacyFontSize: 11
    )

    static let regular = StartScreenLayout(
        isCompact: false,
        showsWordmark: false,
        heroHeight: 140,
        documentScale: 0.92,
        verticalSpacing: 18,
        titleBodySpacing: 10,
        horizontalPadding: 24,
        verticalPadding: 24,
        topSpacer: 4,
        bottomSpacer: 10,
        titleFontSize: 34,
        bodyFontSize: 16,
        promiseRowVerticalPadding: 12,
        promiseRowHorizontalPadding: 16,
        promiseIconSize: 34,
        promiseTitleFontSize: 17,
        promiseSubtitleFontSize: 13,
        buttonHeight: 58,
        privacySpacing: 12,
        privacyFontSize: 12
    )

    static func metrics(forAvailableHeight availableHeight: CGFloat) -> StartScreenLayout {
        if availableHeight < 720 {
            return compressed
        }

        if availableHeight < 800 {
            return compact
        }

        return regular
    }
}
