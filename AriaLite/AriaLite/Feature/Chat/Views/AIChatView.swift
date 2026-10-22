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
                            .accessibilityIdentifier("chat.more")
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

// MARK: - Preview
#Preview {
    AIChatView()
        .environment(AppViewModel())
}
