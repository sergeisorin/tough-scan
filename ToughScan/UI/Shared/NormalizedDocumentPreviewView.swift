import SwiftUI
import ToughScanCore

struct NormalizedDocumentPreviewView: View {
    let snapshot: DocumentSnapshot?
    let confidenceMap: TileConfidenceMap
    let showsOverlay: Bool
    var targetCoordinate: TileCoordinate? = nil
    var recognizedTextBlocks: [RecognizedTextBlock] = []
    var recognizedWords: [RecognizedWord] = []
    var targetWord: RecognizedWord? = nil
    var showsTextLineOverlay = false
    var showsWordOverlay = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 18, y: 10)

            if let snapshot {
                GeometryReader { proxy in
                    ZStack {
                        Image(uiImage: snapshot.previewImage)
                            .resizable()
                            .scaledToFill()
                            .accessibilityLabel("Flattened document preview")

                        if showsOverlay {
                            ConfidenceGridOverlay(
                                map: confidenceMap,
                                targetCoordinate: targetCoordinate
                            )
                                .accessibilityLabel("Confidence overlay aligned to flattened document")
                        }

                        if showsTextLineOverlay && !recognizedTextBlocks.isEmpty {
                            TextLineConfidenceOverlay(blocks: recognizedTextBlocks)
                        }

                        if showsWordOverlay && !recognizedWords.isEmpty {
                            WordConfidenceOverlay(
                                words: recognizedWords,
                                targetWord: targetWord
                            )
                        }
                    }
                    .aspectRatio(
                        snapshot.previewImage.size.width / max(snapshot.previewImage.size.height, 1),
                        contentMode: .fit
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .frame(
                        maxWidth: max(proxy.size.width - 24, 0),
                        maxHeight: max(proxy.size.height - 24, 0)
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
            } else {
                ZStack {
                    ConfidenceGridOverlay(
                        map: confidenceMap,
                        targetCoordinate: targetCoordinate
                    )
                    .opacity(showsOverlay ? 1 : 0.35)

                    VStack(spacing: 10) {
                        Image(systemName: "doc.viewfinder")
                            .font(.title)
                        Text("Waiting for flattened document")
                            .font(.headline)
                        Text("Hold all document edges in frame.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .multilineTextAlignment(.center)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

