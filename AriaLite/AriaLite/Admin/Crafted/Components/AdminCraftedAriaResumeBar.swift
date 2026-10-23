//
//  AdminCraftedAriaResumeBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Quando il pannello è nascosto ma Aria sta lavorando o ha una proposta in pagina: una pillola in basso
//  per riaprirlo, perché Accetta e Scarta non si perdano.
//

import SwiftUI

struct AdminCraftedAriaResumeBar: View {
    let isRunning: Bool
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 8) {
                if isRunning { ProgressView() } else { Image(systemName: "sparkles") }
                Text(isRunning ? "Aria is editing…" : "Review Aria's proposal")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .ariaGlass(in: Capsule(), interactive: true)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
    }
}
