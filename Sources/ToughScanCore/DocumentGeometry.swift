public struct NormalizedPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x.clampedToConfidenceRange
        self.y = y.clampedToConfidenceRange
    }

    func distance(to other: NormalizedPoint) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        return (dx * dx + dy * dy).squareRoot()
    }

    func interpolated(to other: NormalizedPoint, factor: Double) -> NormalizedPoint {
        let clampedFactor = factor.clampedToConfidenceRange
        return NormalizedPoint(
            x: x + ((other.x - x) * clampedFactor),
            y: y + ((other.y - y) * clampedFactor)
        )
    }
}

public struct DocumentQuad: Equatable, Sendable {
    public let topLeft: NormalizedPoint
    public let topRight: NormalizedPoint
    public let bottomRight: NormalizedPoint
    public let bottomLeft: NormalizedPoint

    public static let unit = DocumentQuad(
        topLeft: NormalizedPoint(x: 0, y: 0),
        topRight: NormalizedPoint(x: 1, y: 0),
        bottomRight: NormalizedPoint(x: 1, y: 1),
        bottomLeft: NormalizedPoint(x: 0, y: 1)
    )

    public var area: Double {
        let points = [topLeft, topRight, bottomRight, bottomLeft]
        let sum = zip(points, points.dropFirst() + [points[0]]).reduce(0) { partial, pair in
            partial + (pair.0.x * pair.1.y) - (pair.1.x * pair.0.y)
        }

        return abs(sum) / 2
    }

    public var isValidDocumentShape: Bool {
        area >= 0.05 &&
            topLeft.x < topRight.x &&
            bottomLeft.x < bottomRight.x &&
            topLeft.y < bottomLeft.y &&
            topRight.y < bottomRight.y &&
            topWidth > 0.10 &&
            bottomWidth > 0.10 &&
            leftHeight > 0.10 &&
            rightHeight > 0.10
    }

    public init(
        topLeft: NormalizedPoint,
        topRight: NormalizedPoint,
        bottomRight: NormalizedPoint,
        bottomLeft: NormalizedPoint
    ) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
    }

    public func maxCornerDistance(to other: DocumentQuad) -> Double {
        [
            topLeft.distance(to: other.topLeft),
            topRight.distance(to: other.topRight),
            bottomRight.distance(to: other.bottomRight),
            bottomLeft.distance(to: other.bottomLeft)
        ].max() ?? 0
    }

    public func interpolated(to other: DocumentQuad, factor: Double) -> DocumentQuad {
        DocumentQuad(
            topLeft: topLeft.interpolated(to: other.topLeft, factor: factor),
            topRight: topRight.interpolated(to: other.topRight, factor: factor),
            bottomRight: bottomRight.interpolated(to: other.bottomRight, factor: factor),
            bottomLeft: bottomLeft.interpolated(to: other.bottomLeft, factor: factor)
        )
    }

    private var topWidth: Double { topLeft.distance(to: topRight) }
    private var bottomWidth: Double { bottomLeft.distance(to: bottomRight) }
    private var leftHeight: Double { topLeft.distance(to: bottomLeft) }
    private var rightHeight: Double { topRight.distance(to: bottomRight) }
}

public struct DocumentGeometryObservation: Equatable, Sendable {
    public let quad: DocumentQuad
    public let confidence: Double

    public init(quad: DocumentQuad, confidence: Double) {
        self.quad = quad
        self.confidence = confidence.clampedToConfidenceRange
    }
}

public struct DocumentGeometryStabilizer: Sendable {
    public let smoothingFactor: Double
    public let maxCornerJump: Double

    private var stableObservation: DocumentGeometryObservation?

    public init(smoothingFactor: Double = 0.35, maxCornerJump: Double = 0.20) {
        self.smoothingFactor = smoothingFactor.clampedToConfidenceRange
        self.maxCornerJump = maxCornerJump.clampedToConfidenceRange
    }

    public mutating func update(with observation: DocumentGeometryObservation?) -> DocumentGeometryObservation? {
        guard let observation, observation.quad.isValidDocumentShape else {
            return stableObservation
        }

        guard let current = stableObservation else {
            stableObservation = observation
            return observation
        }

        guard current.quad.maxCornerDistance(to: observation.quad) <= maxCornerJump else {
            return current
        }

        let smoothed = DocumentGeometryObservation(
            quad: current.quad.interpolated(to: observation.quad, factor: smoothingFactor),
            confidence: max(current.confidence, observation.confidence)
        )
        stableObservation = smoothed
        return smoothed
    }
}

