import SwiftUI
import ToughScanCore

struct ConfidenceGridOverlay: View {
    let map: TileConfidenceMap
    var targetCoordinate: TileCoordinate? = nil

    var body: some View {
        GeometryReader { proxy in
            let tileWidth = proxy.size.width / CGFloat(map.width)
            let tileHeight = proxy.size.height / CGFloat(map.height)

            ZStack(alignment: .topLeading) {
                ForEach(map.tiles, id: \.coordinate) { tile in
                    ConfidenceTileView(
                        tile: tile,
                        isTargeted: tile.coordinate == targetCoordinate
                    )
                        .frame(width: tileWidth, height: tileHeight)
                        .position(
                            x: (CGFloat(tile.coordinate.column) * tileWidth) + (tileWidth / 2),
                            y: (CGFloat(tile.coordinate.row) * tileHeight) + (tileHeight / 2)
                        )
                }

                ConfidenceGridLines(columns: map.width, rows: map.height)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct ConfidenceGridLines: View {
    let columns: Int
    let rows: Int

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let tileWidth = proxy.size.width / CGFloat(columns)
                let tileHeight = proxy.size.height / CGFloat(rows)

                for column in 0...columns {
                    let x = CGFloat(column) * tileWidth
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                }

                for row in 0...rows {
                    let y = CGFloat(row) * tileHeight
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                }
            }
            .stroke(Color.primary.opacity(0.35), lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ConfidenceTileView: View {
    let tile: ScanTile
    let isTargeted: Bool

    private var style: ConfidenceStateStyle {
        ConfidenceStateStyle.style(for: tile.state)
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(style.color.opacity(opacity))
                .overlay(
                    Rectangle()
                        .stroke(style.color.opacity(borderOpacity), lineWidth: borderWidth)
                )

            if tile.state != .successful {
                Image(systemName: style.symbolName)
                    .font(.caption)
                    .foregroundStyle(style.color)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel("\(accessibilityPrefix)\(style.title) scan region")
        .accessibilityValue("Confidence \(Int(tile.combinedConfidence * 100)) percent")
    }

    private var opacity: Double {
        switch tile.state {
        case .successful:
            return 0.24
        case .uncertain:
            return 0.36
        case .veryUncertain:
            return 0.44
        case .needsScan:
            return 0.28
        }
    }

    private var borderWidth: CGFloat {
        if isTargeted {
            return 3
        }

        return tile.state == .needsScan ? 1.5 : 1
    }

    private var borderOpacity: Double {
        isTargeted ? 0.95 : 0.55
    }

    private var accessibilityPrefix: String {
        isTargeted ? "Target region, " : ""
    }
}

