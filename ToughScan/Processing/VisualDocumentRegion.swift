import ToughScanCore
import UIKit

struct VisualDocumentRegion: Equatable, Identifiable {
    enum Kind: Equatable {
        case stampOrSignature
        case unknownGraphic
    }

    let id: UUID
    let kind: Kind
    let boundingBox: NormalizedRect
    let confidence: Double
    let image: UIImage

    init(
        id: UUID = UUID(),
        kind: Kind,
        boundingBox: NormalizedRect,
        confidence: Double,
        image: UIImage
    ) {
        self.id = id
        self.kind = kind
        self.boundingBox = boundingBox
        self.confidence = confidence.clampedToUnitRange
        self.image = image
    }

    static func == (lhs: VisualDocumentRegion, rhs: VisualDocumentRegion) -> Bool {
        lhs.id == rhs.id &&
            lhs.kind == rhs.kind &&
            lhs.boundingBox == rhs.boundingBox &&
            lhs.confidence == rhs.confidence
    }
}
