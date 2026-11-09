//
//  AdminMemoryFactModerationBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I due pulsanti grandi del dettaglio: approva (Aria lo usa nelle risposte) e rifiuta. Affiancati,
//  uno sotto l'altro quando il testo è molto grande. Ciascuno compare solo se ha senso per lo stato.
//

import SwiftUI

struct AdminMemoryFactModerationBar: View {
    let canApprove: Bool
    let canReject: Bool
    let isBusy: Bool
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { buttons }
            VStack(spacing: 10) { buttons }
        }
        .disabled(isBusy)
    }

    @ViewBuilder
    private var buttons: some View {
        if canApprove {
            Button(action: onApprove) {
                Label("Approve", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .ariaProminentGlassButtonStyle(tint: .liteAccent, foreground: .liteOnAccent)
        }
        if canReject {
            Button(role: .destructive, action: onReject) {
                Label("Reject", systemImage: "xmark.octagon")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .ariaGlassButtonStyle()
            .tint(.red)
        }
    }
}
