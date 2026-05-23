import CoreGraphics

struct StartScreenLayout: Equatable {
    let isCompact: Bool
    let heroHeight: CGFloat
    let verticalSpacing: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let topSpacer: CGFloat
    let bottomSpacer: CGFloat
    let titleFontSize: CGFloat

    static let compact = StartScreenLayout(
        isCompact: true,
        heroHeight: 126,
        verticalSpacing: 16,
        horizontalPadding: 20,
        verticalPadding: 18,
        topSpacer: 8,
        bottomSpacer: 10,
        titleFontSize: 28
    )

    static let regular = StartScreenLayout(
        isCompact: false,
        heroHeight: 170,
        verticalSpacing: 24,
        horizontalPadding: 22,
        verticalPadding: 24,
        topSpacer: 12,
        bottomSpacer: 18,
        titleFontSize: 32
    )

    static func metrics(forAvailableHeight availableHeight: CGFloat) -> StartScreenLayout {
        availableHeight < 740 ? compact : regular
    }
}
