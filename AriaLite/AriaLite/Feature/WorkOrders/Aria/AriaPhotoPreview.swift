//
//  AriaPhotoPreview.swift
//  AriaLite
//
//  Created by Giovanni Michele on 19/10/26.
//
//  Anteprima rapida di una foto di un passo: a tutto schermo, si chiude con un tocco o con la X.
//

import SwiftUI

/// Una foto da mostrare: già sul server (URL https) o ancora sul telefono (JPEG).
enum AriaPhotoPreviewItem: Identifiable {
    case remote(id: String, url: URL?)
    case local(id: String, jpeg: Data)

    var id: String {
        switch self {
        case .remote(let id, _), .local(let id, _): id
        }
    }
}

struct AriaPhotoPreview: View {
    let item: AriaPhotoPreviewItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .white.opacity(0.3))
            }
            .buttonStyle(.plain)
            .padding(16)
            .accessibilityLabel(Text("Close"))
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
        switch item {
        case .local(_, let jpeg):
            if let image = UIImage(data: jpeg) { Image(uiImage: image).resizable().scaledToFit() }
        case .remote(_, let url):
            // Solo https (AriaURLPolicy): un URL diverso non si scarica e resta il segnaposto.
            if let url = url.flatMap(AriaURLPolicy.image) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFit() }
                    else if phase.error != nil { Image(systemName: "photo").font(.largeTitle).foregroundStyle(.white.opacity(0.6)) }
                    else { ProgressView().tint(.white) }
                }
            } else {
                Image(systemName: "photo").font(.largeTitle).foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}
