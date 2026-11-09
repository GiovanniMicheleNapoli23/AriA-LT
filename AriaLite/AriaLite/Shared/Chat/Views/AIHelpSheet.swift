//
//  AIHelpSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/03/26.
//

import SwiftUI

// Assistente Aria dentro un passo: la chat del backend, col contesto del passo corrente.
// La chat è del chiamante: chiudere il foglio la minimizza soltanto (la conversazione resta e si riapre
// da "Ask AriA"); è il chiamante a azzerarla quando cambia il passo.
struct AIHelpSheet: View {
    let slot: AriaHelpChatSlot
    @Binding var detent: PresentationDetent
    @Environment(\.dismiss) private var dismiss

    /// Fino a questo detent il passo dietro resta toccabile (e leggibile) mentre il foglio è aperto.
    static let detents: Set<PresentationDetent> = [.medium, .large]

    var body: some View {
        NavigationStack {
            Group {
                if let chat = slot.chat {
                    // Chat condivisa, contesto = passo corrente: la sfera al centro con il saluto, come la chat principale.
                    AriaConversation(agentChat: chat)
                        // Un'altra chat (nuovo passo) riparte da zero: bozza e pannelli compresi.
                        .id(ObjectIdentifier(chat))
                } else {
                    Color.clear
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if #available(iOS 26.0, *) {
                        Button(role: .close) { dismiss() }
                    } else {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .accessibilityLabel(Text("Close"))
                    }
                }
            }
        }
        .presentationDetents(Self.detents, selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }
}
