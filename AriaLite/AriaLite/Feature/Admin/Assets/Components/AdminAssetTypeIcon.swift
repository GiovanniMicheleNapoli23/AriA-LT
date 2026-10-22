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

    var body: some View {
        Image(systemName: AdminAssetType.systemImage(for: assetType))
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(Color.liteAccent)
            .frame(width: size, height: size)
            .background(Color.liteAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}
