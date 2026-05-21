import SwiftUI
import ToughScanCore

struct ConfidenceGridOverlay: View {
    let map: TileConfidenceMap

    var body: some View {
        GeometryReader { proxy in
            let tileWidth = proxy.size.width / CGFloat(map.width)
            let tileHeight = proxy.size.height / CGFloat(map.height)

            ZStack(alignment: .topLeading) {
                ForEach(map.tiles, id: \.coordinate) { tile in
                    ConfidenceTileView(tile: tile)
                        .frame(width: tileWidth, height: tileHeight)
                        .position(
                            x: (CGFloat(tile.coordinate.column) * tileWidth) + (tileWidth / 2),
                            y: (CGFloat(tile.coordinate.row) * tileHeight) + (tileHeight / 2)
                        )
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct ConfidenceTileView: View {
    let tile: ScanTile

    private var style: ConfidenceStateStyle {
        ConfidenceStateStyle.style(for: tile.state)
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(style.color.opacity(opacity))
                .overlay(
                    Rectangle()
                        .stroke(style.color.opacity(0.55), lineWidth: borderWidth)
                )

            if tile.state != .successful {
                Image(systemName: style.symbolName)
                    .font(.caption)
                    .foregroundStyle(style.color)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel("\(style.title) scan region")
        .accessibilityValue("Confidence \(Int(tile.combinedConfidence * 100)) percent")
    }

    private var opacity: Double {
        switch tile.state {
        case .successful:
            return 0.18
        case .uncertain:
            return 0.28
        case .veryUncertain:
            return 0.34
        case .needsScan:
            return 0.20
        }
    }

    private var borderWidth: CGFloat {
        tile.state == .needsScan ? 1.5 : 1
    }
}

