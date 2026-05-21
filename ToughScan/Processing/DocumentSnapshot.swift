import UIKit

struct DocumentSnapshot: Identifiable {
    let id: UUID
    let image: UIImage
    let visualQuality: Double
    let createdAt: Date

    init(
        id: UUID = UUID(),
        image: UIImage,
        visualQuality: Double,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.image = image.downscaledForDocumentPreview()
        self.visualQuality = min(max(visualQuality, 0), 1)
        self.createdAt = createdAt
    }

    func isBetterThan(_ other: DocumentSnapshot?) -> Bool {
        guard let other else {
            return true
        }

        return visualQuality > other.visualQuality
    }
}

private extension UIImage {
    func downscaledForDocumentPreview(maxEdge: CGFloat = 1024) -> UIImage {
        let longestEdge = max(size.width, size.height)
        guard longestEdge > maxEdge else {
            return self
        }

        let scaleFactor = maxEdge / longestEdge
        let targetSize = CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

