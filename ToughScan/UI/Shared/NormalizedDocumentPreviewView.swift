import SwiftUI
import ToughScanCore

struct NormalizedDocumentPreviewView: View {
    let snapshot: DocumentSnapshot?
    let confidenceMap: TileConfidenceMap
    let showsOverlay: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 18, y: 10)

            if let snapshot {
                GeometryReader { proxy in
                    ZStack {
                        Image(uiImage: snapshot.image)
                            .resizable()
                            .scaledToFill()
                            .accessibilityLabel("Flattened document preview")

                        if showsOverlay {
                            ConfidenceGridOverlay(map: confidenceMap)
                                .accessibilityLabel("Confidence overlay aligned to flattened document")
                        }
                    }
                    .aspectRatio(
                        snapshot.image.size.width / max(snapshot.image.size.height, 1),
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
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

