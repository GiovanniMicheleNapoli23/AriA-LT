//
//  AriaRemoteThumbnail.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  Anteprima di un'immagine remota nella cornice di una risposta: si scarica, si decodifica già ridotta
//  alla misura della cornice (non a piena risoluzione) e si tiene in una piccola cache in memoria.
//

import ImageIO
import SwiftUI
import UIKit

/// Al posto di `AsyncImage`, che decodifica l'immagine intera anche se la cornice è di 150 × 110 punti.
struct AriaRemoteThumbnail: View {
    let url: URL
    /// La cornice in punti: l'immagine la riempie (scaledToFill).
    let size: CGSize

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color(.tertiarySystemFill)
            }
        }
        .task(id: url) {
            image = await AriaThumbnailLoader.image(for: url, frame: size, scale: displayScale)
        }
    }
}

/// Scarica e riduce le immagini delle risposte. La cache regge poche decine di anteprime.
private nonisolated enum AriaThumbnailLoader {
    /// NSCache è thread-safe; le anteprime sono immutabili.
    nonisolated(unsafe) private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 60
        return cache
    }()

    /// Dalla cache se c'è (subito, senza rete); altrimenti scarica e riduce fuori dal main thread.
    @MainActor
    static func image(for url: URL, frame: CGSize, scale: CGFloat) async -> UIImage? {
        let key = "\(url.absoluteString)@\(scale)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let loaded = await load(url, frame: frame, scale: scale) else { return nil }
        cache.setObject(loaded, forKey: key)
        return loaded
    }

    @concurrent
    private static func load(_ url: URL, frame: CGSize, scale: CGFloat) async -> UIImage? {
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = CGFloat((properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? 0)
        let height = CGFloat((properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? 0)
        guard width > 0, height > 0 else { return nil }
        // L'immagine riempie la cornice: la scala è quella che copre entrambi i lati; mai più grande dell'originale.
        let fill = max(frame.width * scale / width, frame.height * scale / height)
        let longSide = (max(width, height) * min(1, fill)).rounded(.up)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: longSide,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: thumbnail, scale: scale, orientation: .up)
    }
}
