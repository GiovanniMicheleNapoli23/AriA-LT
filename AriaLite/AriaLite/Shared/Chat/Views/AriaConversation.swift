//
//  AriaConversation.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La conversazione riusabile (chat + composer): la schermata principale e l'assistente di un passo.
//  È la chat della web app (AriaAgentChatView); senza backend collegato si chiede di collegarlo.
//  La logica sta in AriaConversationViewModel.
//

import SwiftUI

struct AriaConversation: View {
    @Environment(AppViewModel.self) private var app

    /// Chat del chiamante (la schermata tiene quella principale); nil = una chat propria con il contesto del passo.
    var agentChat: AriaAgentChat? = nil
    /// Contesto già scritto (ordine e passo di un lavoro Aria): viaggia col primo messaggio.
    var contextText: String? = nil
    var showsEmptyState: Bool = true

    var body: some View {
        AriaConversationContent(backend: app.backend, agentChat: agentChat, contextText: contextText,
                                showsEmptyState: showsEmptyState)
    }
}

private struct AriaConversationContent: View {
    let showsEmptyState: Bool
    @State private var model: AriaConversationViewModel

    /// La chat del chiamante non cambia per questa vista (chi la cambia cambia anche identità, `.id`).
    init(backend: AriaBackend, agentChat: AriaAgentChat?, contextText: String?, showsEmptyState: Bool) {
        _model = State(initialValue: AriaConversationViewModel(backend: backend, agentChat: agentChat, contextText: contextText))
        self.showsEmptyState = showsEmptyState
    }

    var body: some View {
        if model.isConnected {
            if let chat = model.chat {
                AriaAgentChatView(chat: chat, backend: model.backend, showsEmptyState: showsEmptyState, voice: model.voice)
                    // Il view model della schermata nasce con la chat: un'altra chat, una schermata nuova.
                    .id(ObjectIdentifier(chat))
            } else {
                Color(.systemGroupedBackground).onAppear { model.makeOwnChatIfNeeded() }
            }
        } else {
            disconnected
        }
    }

    /// Nessun backend collegato: non c'è una chat di ripiego, solo il modo per collegarlo.
    private var disconnected: some View {
        VStack(spacing: 20) {
            AriaOrb(radius: 0.8)
                .frame(width: 108, height: 108)
                .shadow(color: Color.accentColor.opacity(0.28), radius: 18, x: 0, y: 8)

            VStack(spacing: 8) {
                Text("Hi, I'm Aria")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("Connect to the Aria server to start chatting.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button { model.connect() } label: {
                Label("Connect to the Aria server", systemImage: "bolt.horizontal.circle")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $model.showConnection) {
            AriaConnectionSheet(backend: model.backend)
        }
    }
}
