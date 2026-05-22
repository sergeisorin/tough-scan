import CoreGraphics

public enum NormalizedCoordinateSpace: Sendable {
    case imageTopLeft
    case visionBottomLeft
}

public extension NormalizedRect {
    func converted(
        from source: NormalizedCoordinateSpace,
        to destination: NormalizedCoordinateSpace
    ) -> NormalizedRect {
        guard source != destination else {
            return self
        }

        return NormalizedRect(
            x: x,
            y: 1 - y - height,
            width: width,
            height: height
        )
    }

    func pixelRect(
        in size: CGSize,
        from source: NormalizedCoordinateSpace = .imageTopLeft,
        origin: CGPoint = .zero
    ) -> CGRect {
        let imageTopLeftRect = converted(from: source, to: .imageTopLeft)

        return CGRect(
            x: origin.x + (imageTopLeftRect.x * size.width),
            y: origin.y + (imageTopLeftRect.y * size.height),
            width: imageTopLeftRect.width * size.width,
            height: imageTopLeftRect.height * size.height
        )
    }
}
