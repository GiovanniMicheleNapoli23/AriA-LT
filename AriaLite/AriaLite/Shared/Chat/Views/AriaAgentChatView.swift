//
//  AriaAgentChatView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 25/09/26.
//
//  La chat con il backend Aria, come quella della web: messaggi in streaming,
//  suggerimenti iniziali, scelta dello stabilimento, domande guidate (al posto
//  del composer), conferma LOTO, comandi rapidi, errori con "Riprova" e un
//  pulsante per tornare in fondo quando si sta rileggendo.
//
//  Qui solo la composizione: lo stato sta in AriaAgentChatViewModel, i pezzi nei file accanto.
//

import SwiftUI

struct AriaAgentChatView: View {
    private let showsEmptyState: Bool

    @State private var model: AriaAgentChatViewModel
    @Namespace private var orbNamespace
    @FocusState private var inputFocused: Bool

    /// Il view model nasce una volta sola con questa `chat`: per un'altra chat il chiamante
    /// cambia identità alla vista (`.id`), così lo stato della schermata riparte da capo.
    init(chat: AriaAgentChat, backend: AriaBackend, showsEmptyState: Bool = true, voice: AriaVoiceViewModel? = nil) {
        _model = State(initialValue: AriaAgentChatViewModel(chat: chat, backend: backend, voice: voice))
        self.showsEmptyState = showsEmptyState
    }

    var body: some View {
        ScrollViewReader { proxy in
            messagesArea(proxy)
                // Primo invio: la sfera grande diventa quella piccola sotto la risposta.
                .animation(.spring(response: 0.55, dampingFraction: 0.82), value: model.messages.isEmpty)
                .overlay(alignment: .bottom) { jumpToBottomButton(proxy) }
                // Il fondo sta sopra i messaggi, non sotto: con il vetro della barra si vedono scorrere dietro.
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    AriaChatDock(model: model, inputFocused: $inputFocused) {
                        if let id = model.pendingInterruptMessageID {
                            withAnimation(.snappy) { proxy.scrollTo(id, anchor: .bottom) }
                        }
                    }
                }
        }
        .background(Color(.systemGroupedBackground))
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { model.viewportHeight = $0 }
        .animation(.snappy(duration: 0.3), value: model.activeQuestionID)
        .animation(.snappy(duration: 0.3), value: model.questionCollapsed)
        .animation(.snappy(duration: 0.25), value: model.notice)
        .animation(.snappy(duration: 0.25), value: model.turnError)
        .animation(.snappy(duration: 0.25), value: model.isOnline)
        .animation(.snappy(duration: 0.3), value: model.hasBlockingProcedure)
        .animation(.snappy(duration: 0.3), value: model.learningCollapsed)
        .onChange(of: model.activeQuestionID) { model.questionChanged() }
        .onChange(of: model.chat.activeLearning?.messageId) { _, id in model.announceLearning(id) }
        .onChange(of: model.chat.learningReveal) { model.revealLearning() }
        .onAppear { model.showCurrentLearning() }
        .ariaChatHaptics(model)
        .ariaLinks(model.webURL)
        .task { await model.restore() }
        .sheet(item: Binding(get: { model.lotoInterrupt.map(LotoItem.init) }, set: { _ in })) { item in
            AriaLotoSheet(interrupt: item.interrupt) { model.resumeLoto($0) }
        }
        .sheet(item: $model.pendingCloseout) { choice in
            AriaCloseoutSheet(chat: model.chat, choice: choice)
        }
    }

    private struct LotoItem: Identifiable {
        let interrupt: AriaInterrupt
        var id: String { interrupt.interruptId }
    }

    /// Cronologia in caricamento e chat vuota stanno fuori dalla scroll view dei messaggi: una schermata
    /// alta quanto lo schermo (containerRelativeFrame) dentro una ScrollView ancorata in basso e osservata
    /// entrava in un ciclo di layout infinito — main thread al 100% e chat inutilizzabile.
    @ViewBuilder
    private func messagesArea(_ proxy: ScrollViewProxy) -> some View {
        if model.isLoadingHistory {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.messages.isEmpty && showsEmptyState {
            AriaChatEmptyState(model: model, orbNamespace: orbNamespace) { suggestion in
                inputFocused = false
                model.sendSuggestion(suggestion)
            }
            // Con min e max il riquadro prende sempre lo spazio offerto, anche quando il contenuto è più
            // alto (tastiera appena aperta): così la misura scende e scatta il layout compatto.
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .onGeometryChange(for: CGFloat.self, of: \.size.height) { model.emptyHeight = $0 }
            .contentShape(Rectangle())
            .onTapGesture { inputFocused = false }
        } else {
            AriaChatMessagesList(model: model, orbNamespace: showsEmptyState ? orbNamespace : nil, proxy: proxy)
        }
    }

    @ViewBuilder
    private func jumpToBottomButton(_ proxy: ScrollViewProxy) -> some View {
        if model.showsJumpToBottom {
            AriaChatJumpToBottomButton(isStreaming: model.isStreaming) {
                model.jumpToBottom()
                withAnimation(.snappy) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .padding(.bottom, 10)
            .transition(.scale(scale: 0.6).combined(with: .opacity))
        }
    }
}
