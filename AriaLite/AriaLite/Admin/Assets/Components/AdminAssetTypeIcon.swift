//
//  AdminAssetTypeIcon.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'icona del tipo di asset in un quadrato tinto col colore dell'app.
//

import SwiftUI

struct AdminAssetTypeIcon: View {
    let assetType: String?
    var size: CGFloat = 40
    /// `size` è quella a testo "Large": il quadrato cresce col Dynamic Type come il testo accanto.
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        let side = size * scale
        Image(systemName: AdminAssetType.systemImage(for: assetType))
            .font(.system(size: side * 0.42, weight: .semibold))
            .foregroundStyle(Color.liteAccent)
            .frame(width: side, height: side)
            .background(Color.liteAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: side * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}
