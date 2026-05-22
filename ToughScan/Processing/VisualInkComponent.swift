import CoreGraphics

struct VisualInkComponent {
    private(set) var minX = Int.max
    private(set) var minY = Int.max
    private(set) var maxX = Int.min
    private(set) var maxY = Int.min
    private(set) var pixelCount = 0

    mutating func include(x: Int, y: Int) {
        minX = min(minX, x)
        minY = min(minY, y)
        maxX = max(maxX, x)
        maxY = max(maxY, y)
        pixelCount += 1
    }

    var pixelRect: CGRect {
        CGRect(
            x: minX,
            y: minY,
            width: max(0, maxX - minX + 1),
            height: max(0, maxY - minY + 1)
        )
    }
}
