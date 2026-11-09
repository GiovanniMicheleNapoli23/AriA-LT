//
//  AdminCraftedUndoBanner.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  L'avviso in basso dopo l'eliminazione di un artifact, con Annulla (il toast della web).
//

import SwiftUI

struct AdminCraftedUndoBanner: View {
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Text("Artifact deleted")
                .font(.subheadline)
            Button("Undo", action: undo)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.liteAccent)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .ariaGlass(in: Capsule())
        .accessibilityElement(children: .contain)
    }
}
