//
//  AdminCraftedArtifactBanners.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Le due strisce sopra la conversazione: "Modificato" (quale versione, di chi, quando, e "Vedi modifiche",
//  perché chi legge non scambi una tabella cambiata a mano per i numeri di Aria) e "Aria ha bisogno di
//  qualche dettaglio" con il pulsante per rispondere in chat.
//

import SwiftUI

struct AdminCraftedEditedBanner: View {
    let line: String
    let seeChanges: () -> Void

    var body: some View {
        AriaCard {
            HStack(spacing: 6) {
                Image(systemName: "pencil")
                Text("Edited")
            }
            .font(.subheadline.weight(.semibold))
            Text(line).font(.footnote).foregroundStyle(.secondary)
            Button("See changes", action: seeChanges)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderless)
        }
    }
}

struct AdminCraftedNeedsChatBanner: View {
    let openChat: () -> Void

    var body: some View {
        AriaCard {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.text.bubble.right")
                Text("Aria needs a few more details")
            }
            .font(.subheadline.weight(.semibold))
            Text("Answer in the chat: as soon as Aria makes it, it shows up here.")
                .font(.footnote).foregroundStyle(.secondary)
            Button(action: openChat) { Label("Answer in the chat", systemImage: "bubble.left") }
                .ariaGlassButtonStyle()
        }
    }
}
