import SwiftUI
import ToughScanCore

struct WordConfidenceOverlay: View {
    let words: [RecognizedWord]
    var targetWord: RecognizedWord?

    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                WordConfidenceMark(
                    word: word,
                    rect: rect(for: word.boundingBox, in: proxy.size),
                    isTargeted: word == targetWord
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(words.isEmpty)
    }

    private func rect(for boundingBox: NormalizedRect, in size: CGSize) -> CGRect {
        boundingBox.pixelRect(in: size, from: .visionBottomLeft)
    }
}

private struct WordConfidenceMark: View {
    let word: RecognizedWord
    let rect: CGRect
    let isTargeted: Bool

    private var style: ConfidenceStateStyle {
        ConfidenceStateStyle.style(for: word.state)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if word.state == .successful {
                Rectangle()
                    .fill(style.color.opacity(isTargeted ? 1 : 0.82))
                    .frame(height: isTargeted ? 2 : 1)
                    .frame(width: max(rect.width, 2))
                    .position(x: rect.midX, y: rect.maxY + 2)
            } else {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(style.color.opacity(word.state == .needsScan ? 0.06 : 0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(style.color.opacity(isTargeted ? 1 : 0.86), lineWidth: isTargeted ? 2 : 1.25)
                    )
                    .frame(width: max(rect.width, 3), height: max(rect.height, 3))
                    .position(x: rect.midX, y: rect.midY)

                Image(systemName: style.symbolName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 15, height: 15)
                    .background(style.color)
                    .clipShape(Circle())
                    .position(x: rect.maxX, y: rect.minY)
            }
        }
        .accessibilityLabel("\(word.text), \(style.title), confidence \(Int(word.confidence * 100)) percent")
    }
}
