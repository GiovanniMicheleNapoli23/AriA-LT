//
//  AriaChatDock.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il fondo della chat: avvisi, poi la domanda guidata, la procedura o il Real-time Learning
//  (al posto del composer) oppure il composer.
//

import SwiftUI

struct AriaChatDock: View {
    @Bindable var model: AriaAgentChatViewModel
    let inputFocused: FocusState<Bool>.Binding
    /// Il composer chiede di mostrare la pausa in attesa (approvazione o LOTO) nella lista.
    var onShowPending: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        VStack(spacing: 8) {
            notices

            panel
        }
        // iPad: stessa colonna dei messaggi.
        .ariaReadableWidth()
        .padding(.top, 6)
        // Il pannello segue la chat con un'animazione esplicita: cambia quando finisce lo stream,
        // e l'animazione implicita lì non partiva (il pannello compariva di colpo).
        .onChange(of: model.wantedPanel) { _, new in
            withAnimation(.spring(duration: 0.45, bounce: 0.12)) { model.panel = new }
        }
        .onAppear { model.panel = model.wantedPanel }
    }

    /// In orizzontale con la tastiera restano ~150pt: gli avvisi scorrono in un quarto della chat
    /// invece di spingere il composer sotto la barra.
    @ViewBuilder
    private var notices: some View {
        let content = AriaChatDockNotices(model: model, inputFocused: inputFocused)
            .padding(.horizontal, 12)
        if verticalSizeClass == .compact {
            ScrollView {
                content.onGeometryChange(for: CGFloat.self, of: \.size.height) { model.noticesHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: model.noticesMaxHeight)
        } else {
            content
        }
    }

    @ViewBuilder
    private var panel: some View {
        switch model.panel {
        case .learned(let outcome):
            AriaLearningOutcomePanel(outcome: outcome, chat: model.chat)
                .padding(.top, 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .learning(let messageId, let request):
            // Stesso posto e stesso comportamento della domanda guidata, ma la risposta insegna ad Aria:
            // non diventa un turno di chat e la procedura in corso non si interrompe.
            AriaElicitationPanel(elicitation: request.elicitation(messageId: messageId),
                                 kind: .learning(reason: request.reasonText),
                                 maxOptionsHeight: model.optionsHeight(share: 0.6)) { text, _ in
                model.answerLearning(messageId: messageId, request: request, feedback: text)
            } onMinimize: {
                model.collapseLearning()
            }
            .padding(.top, 4)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        case .procedure(let messageId, let list):
            // Prima la checklist, poi la domanda: finché mancano task si risponde alla procedura.
            AriaProcedureDock(list: list, messageId: messageId, chat: model.chat)
                .padding(.top, 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .question(let question):
            AriaElicitationPanel(elicitation: question, maxOptionsHeight: model.optionsHeight(share: 0.7)) { text, details in
                model.answerQuestion(question, text: text, details: details)
            } onMinimize: {
                model.collapseQuestion()
            }
            .padding(.top, 4)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        case .composer:
            AriaChatComposer(chat: model.chat, backend: model.backend, voice: model.voice, draft: $model.draft,
                             inputFocused: inputFocused, onShowPending: onShowPending)
                .transition(.opacity)
        }
    }
}

/// Sopra il pannello: rete, stabilimento, conferme, errori, chat vocale e domande ridotte a pillola.
private struct AriaChatDockNotices: View {
    let model: AriaAgentChatViewModel
    let inputFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: 8) {
            if model.showsNetworkNotice {
                AriaOfflineNotice(detail: "The AI chat needs a connection. Tasks and the calendar keep working offline.")
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if model.needsPlant {
                AriaPlantGuardBanner(backend: model.backend)
            }
            if let notice = model.notice {
                AriaChatNoticeBanner(notice: notice) { model.dismissNotice() }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if let error = model.turnError {
                errorBanner(error)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if let voice = model.voice, model.showsVoiceSession {
                VoiceSessionOverlay(voice: voice)
            }
            if let learning = model.collapsedLearning {
                AriaElicitationPill(elicitation: learning, isLearning: true) {
                    inputFocused.wrappedValue = false
                    model.expandLearning()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let question = model.collapsedQuestion {
                AriaElicitationPill(elicitation: question) {
                    inputFocused.wrappedValue = false
                    model.expandQuestion()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    /// Il sistema non si raggiunge: avviso ambra con "Riprova" (rimanda l'ultima domanda, se è fallita).
    @ViewBuilder
    private func errorBanner(_ error: String) -> some View {
        if model.turnErrorIsOffline {
            AriaOfflineNotice(onRetry: model.canRetry ? { model.retryAfterOfflineError() } : nil,
                              onDismiss: { model.dismissError() })
        } else {
            AriaChatErrorBanner(error: error, onRetry: model.canRetry ? { model.retryFailedTurn() } : nil,
                                onDismiss: { model.dismissError() })
        }
    }
}
