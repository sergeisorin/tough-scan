import SwiftUI
import ToughScanCore

struct TextLineConfidenceOverlay: View {
    let blocks: [RecognizedTextBlock]

    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                if let boundingBox = block.boundingBox {
                    TextLineConfidenceBox(
                        block: block,
                        rect: rect(for: boundingBox, in: proxy.size)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func rect(for boundingBox: NormalizedRect, in size: CGSize) -> CGRect {
        CGRect(
            x: boundingBox.x * size.width,
            y: (1 - boundingBox.y - boundingBox.height) * size.height,
            width: boundingBox.width * size.width,
            height: boundingBox.height * size.height
        )
    }
}

private struct TextLineConfidenceBox: View {
    let block: RecognizedTextBlock
    let rect: CGRect

    private var state: ScanConfidenceState {
        ScanConfidenceState.state(for: block.confidence)
    }

    private var style: ConfidenceStateStyle {
        ConfidenceStateStyle.style(for: state)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(style.color.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(style.color.opacity(0.85), lineWidth: lineWidth)
            )
            .frame(width: max(rect.width, 2), height: max(rect.height, 2))
            .position(x: rect.midX, y: rect.midY)
            .accessibilityLabel("Text line \(block.text), confidence \(Int(block.confidence * 100)) percent")
            .accessibilityValue(style.title)
    }

    private var lineWidth: CGFloat {
        switch state {
        case .successful:
            return 1
        case .uncertain:
            return 1.5
        case .veryUncertain, .needsScan:
            return 2
        }
    }
}

