//
//  AIChatView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 31/03/26.
//

import SwiftUI

// MARK: - AIChatView (schermata principale)
struct AIChatView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var closeout: AriaCloseoutChoice?
    @State private var showingOptions = false
    /// La chiusura intervento scelta dal menu "···": parte quando il menu si è chiuso (un foglio alla volta).
    @State private var closeOutAfterOptions = false

    private var backend: AriaBackend { viewModel.backend }
    private var chat: AriaAgentChat { viewModel.mainChat }

    /// Il titolo che il backend dà alla sessione; finché non arriva, la prima domanda dell'operatore.
    private var title: String {
        guard backend.isReady, let first = chat.messages.first(where: { $0.role == .user })?.text else {
            return String(localized: "New chat")
        }
        if let saved = viewModel.sessions.sessions.first(where: { $0.sessionId == chat.sessionId })?.title,
           !saved.isEmpty {
            return saved
        }
        return first
    }

    var body: some View {
        NavigationStack {
            AriaConversation(agentChat: chat, showsEmptyState: true)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                    // Solo il titolo: server e stabilimento si gestiscono nel profilo (Impostazioni).
                    ToolbarItem(placement: .principal) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .frame(maxWidth: 240)
                            .contentTransition(.opacity)
                            .animation(.easeInOut(duration: 0.25), value: title)
                    }
                    // La nuova chat sta nella barra laterale; qui lo storico della procedura,
                    // il microfono e la chiusura intervento.
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("More", systemImage: "ellipsis") { showingOptions = true }
                    }
                }
                .sheet(isPresented: $showingOptions, onDismiss: {
                    guard closeOutAfterOptions else { return }
                    closeOutAfterOptions = false
                    closeout = AriaCloseoutChoice(workOrder: true, report: false)
                }) {
                    AriaChatOptionsSheet(chat: chat, onCloseOut: backend.isReady ? { closeOutAfterOptions = true } : nil)
                }
                .sheet(item: $closeout) { choice in
                    AriaCloseoutSheet(chat: chat, choice: choice)
                }
                // A turno finito il backend ha (ri)generato il titolo: si ricaricano le sessioni.
                .onChange(of: chat.isStreaming) { _, streaming in
                    if !streaming, backend.isReady { Task { await viewModel.sessions.load() } }
                }
        }
    }
}

// MARK: - Reusable conversation (chat + input)
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

// MARK: - Preview
#Preview {
    AIChatView()
        .environment(AppViewModel())
}
