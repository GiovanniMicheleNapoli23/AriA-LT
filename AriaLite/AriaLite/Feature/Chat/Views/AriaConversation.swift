//
//  AriaConversation.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La conversazione riusabile (chat + composer): la schermata principale e l'assistente di un passo.
//

import SwiftUI

// Usata dalla schermata principale (showsEmptyState) e dall'assistente di un passo (contextText).
// È la chat della web app (AriaAgentChatView); senza backend collegato si chiede di collegarlo.
struct AriaConversation: View {
    @Environment(AppViewModel.self) private var viewModel

    /// Chat del chiamante (la schermata tiene quella principale); nil = una chat propria con il contesto del passo.
    var agentChat: AriaAgentChat? = nil
    /// Contesto già scritto (ordine e passo di un lavoro Aria): viaggia col primo messaggio.
    var contextText: String? = nil
    var showsEmptyState: Bool = true

    @State private var ownAgentChat: AriaAgentChat?
    @State private var voice = AriaVoiceViewModel()
    @State private var showConnection = false

    var body: some View {
        if viewModel.backend.isReady {
            if let chat = agentChat ?? ownAgentChat {
                AriaAgentChatView(chat: chat, backend: viewModel.backend, showsEmptyState: showsEmptyState, voice: voice)
                    // Il view model della schermata nasce con la chat: un'altra chat, una schermata nuova.
                    .id(ObjectIdentifier(chat))
            } else {
                Color(.systemGroupedBackground).onAppear {
                    // Contesto del passo: viaggia col primo messaggio (modo A della guida).
                    let context = contextText.map { "[Work order context]\n\($0)" }
                    ownAgentChat = AriaAgentChat(backend: viewModel.backend, context: context)
                }
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
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Connect to the Aria server to start chatting.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button { showConnection = true } label: {
                Label("Connect to the Aria server", systemImage: "bolt.horizontal.circle")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showConnection) {
            AriaConnectionSheet(backend: viewModel.backend)
        }
    }
}
