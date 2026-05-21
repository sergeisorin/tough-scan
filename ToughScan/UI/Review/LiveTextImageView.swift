import SwiftUI
import UIKit
import VisionKit

struct LiveTextImageView: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = true
        imageView.addInteraction(context.coordinator.interaction)
        return imageView
    }

    func updateUIView(_ imageView: UIImageView, context: Context) {
        imageView.image = image
        context.coordinator.analyze(image: image)
    }

    @MainActor
    final class Coordinator {
        let interaction = ImageAnalysisInteraction()
        private let analyzer = ImageAnalyzer()
        private var analysisTask: Task<Void, Never>?

        func analyze(image: UIImage) {
            interaction.preferredInteractionTypes = []
            interaction.analysis = nil
            analysisTask?.cancel()

            guard ImageAnalyzer.isSupported else {
                return
            }

            analysisTask = Task { [analyzer, interaction] in
                let configuration = ImageAnalyzer.Configuration([.text, .machineReadableCode])

                do {
                    let analysis = try await analyzer.analyze(image, configuration: configuration)
                    guard !Task.isCancelled else {
                        return
                    }

                    await MainActor.run {
                        interaction.analysis = analysis
                        interaction.preferredInteractionTypes = .automatic
                    }
                } catch {
                    await MainActor.run {
                        interaction.analysis = nil
                        interaction.preferredInteractionTypes = []
                    }
                }
            }
        }

        deinit {
            analysisTask?.cancel()
        }
    }
}
