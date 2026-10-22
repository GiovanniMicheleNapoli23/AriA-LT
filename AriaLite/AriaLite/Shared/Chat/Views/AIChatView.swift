//
//  AIChatView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 31/03/26.
//
//  La schermata Chat: titolo, menu "···" e chiusura intervento attorno alla conversazione.
//  La logica sta in AIChatViewModel.
//

import SwiftUI

// MARK: - AIChatView (schermata principale)
struct AIChatView: View {
    @Environment(AppViewModel.self) private var app

    var body: some View {
        AIChatScreen(app: app)
    }
}

private struct AIChatScreen: View {
    @State private var model: AIChatViewModel

    /// L'AppViewModel è uno per tutta l'app: il view model nasce una volta sola.
    init(app: AppViewModel) {
        _model = State(initialValue: AIChatViewModel(app: app))
    }

    var body: some View {
        NavigationStack {
            AriaConversation(agentChat: model.chat, showsEmptyState: true)
                .navigationTitle(model.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                    // Solo il titolo: server e stabilimento si gestiscono nel profilo (Impostazioni).
                    ToolbarItem(placement: .principal) {
                        Text(model.title)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .frame(maxWidth: 240)
                            .contentTransition(.opacity)
                            .animation(.easeInOut(duration: 0.25), value: model.title)
                    }
                    // La nuova chat sta nella barra laterale; qui lo storico della procedura,
                    // il microfono e la chiusura intervento.
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("More", systemImage: "ellipsis") { model.showOptions() }
                            .accessibilityIdentifier("chat.more")
                    }
                }
                .sheet(isPresented: $model.showingOptions, onDismiss: { model.optionsDismissed() }) {
                    AriaChatOptionsSheet(chat: model.chat,
                                         onCloseOut: model.offersCloseOut ? { model.closeOutAfterOptionsDismiss() } : nil)
                }
                .sheet(item: $model.closeout) { choice in
                    AriaCloseoutSheet(chat: model.chat, choice: choice)
                }
                .onChange(of: model.chat.isStreaming) { _, streaming in model.streamingChanged(streaming) }
        }
    }
}

// MARK: - Preview
#Preview {
    AIChatView()
        .environment(AppViewModel())
}
