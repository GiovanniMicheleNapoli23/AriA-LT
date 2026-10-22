//
//  AriaAgentChatViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo stato della schermata di chat: bozza, suggerimenti iniziali, pannello in fondo, Real-time
//  Learning, scorrimento. La conversazione vera resta in AriaAgentChat: qui si legge attraverso di
//  lei, senza copiarne lo stato.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class AriaAgentChatViewModel {
    let chat: AriaAgentChat
    let backend: AriaBackend

    // MARK: - State

    var draft = ""
    let greeting = AriaChatCopy.greeting()
    /// I chip di partenza (GET /v1/chat/suggestions): vuoti = nessun chip.
    private(set) var suggestions: [String] = []
    /// Altezza libera della chat vuota (senza barra, composer e tastiera): decide il layout.
    var emptyHeight: CGFloat = 700
    /// La domanda guidata è stata ridotta a pillola (si legge o si scrive liberamente).
    var questionCollapsed = false
    /// La domanda di Real-time Learning in fondo: compare quando l'avviso rientra nella Dynamic Island.
    private(set) var learningShownId: String?
    var learningCollapsed = false
    /// Il pannello mostrato in fondo: segue `wantedPanel` con un'animazione (la decide la vista).
    var panel: AriaChatBottomPanel = .composer
    var scroll = AriaChatScrollFollow()
    var viewportHeight: CGFloat = 700
    /// Parte visibile della lista (senza barre e pannello in basso) e altezza dell'ultima domanda:
    /// servono a tenere la domanda in cima mentre la risposta cresce sotto (come Claude).
    var visibleHeight: CGFloat = 600
    private var turnQuestionHeight: CGFloat = 0

    init(chat: AriaAgentChat, backend: AriaBackend) {
        self.chat = chat
        self.backend = backend
    }

    // MARK: - Derived

    var isComposing: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var salutation: String {
        AriaChatCopy.salutation(name: backend.mobileAccount?.name)
    }

    var emptyLayout: AriaChatEmptyLayout {
        AriaChatEmptyLayout(height: emptyHeight, hasSuggestions: !suggestions.isEmpty)
    }

    var canSendSuggestion: Bool {
        !chat.isStreaming && chat.pendingInterrupt == nil
    }

    var lotoInterrupt: AriaInterrupt? {
        guard let pause = chat.pendingInterrupt, pause.kind == .loto, !chat.isStreaming else { return nil }
        return pause
    }

    /// L'ultimo turno è fallito: si può rimandare la stessa domanda.
    var failedTurn: AriaAgentMessage? {
        guard !chat.isStreaming, let last = chat.messages.last, last.role == .assistant, last.error != nil,
              last.interrupt == nil else { return nil }
        return last
    }

    var showsJumpToBottom: Bool {
        scroll.showsJumpToBottom && !chat.messages.isEmpty
    }

    /// Il Real-time Learning passa davanti: è appena stato annunciato dall'isola e non blocca niente
    /// (con "Non ora" si riduce a pillola e tornano la procedura, la domanda o il composer).
    var wantedPanel: AriaChatBottomPanel {
        if let outcome = chat.learningOutcome { return .learned(outcome) }
        if let (messageId, request, _) = chat.activeLearning, learningShownId == messageId, !learningCollapsed {
            return .learning(messageId: messageId, request: request)
        }
        if let (messageId, list) = chat.blockingTaskList { return .procedure(messageId: messageId, list: list) }
        if let (_, question) = chat.activeElicitation, !questionCollapsed { return .question(question) }
        return .composer
    }

    /// La domanda di Real-time Learning ridotta a pillola sopra il composer.
    var collapsedLearning: AriaElicitation? {
        guard let (messageId, request, _) = chat.activeLearning, learningShownId == messageId,
              learningCollapsed else { return nil }
        return request.elicitation(messageId: messageId)
    }

    /// La domanda guidata ridotta a pillola (non durante una procedura, che ha la precedenza).
    var collapsedQuestion: AriaElicitation? {
        guard let (_, question) = chat.activeElicitation, questionCollapsed, chat.blockingTaskList == nil else { return nil }
        return question
    }

    // MARK: - Turno corrente

    /// L'ultima domanda dell'operatore e la risposta che la segue (se è l'ultimo messaggio).
    private var turnQuestionID: String? {
        chat.messages.last(where: { $0.role == .user })?.id
    }

    private var turnReplyID: String? {
        guard let last = chat.messages.last, last.role == .assistant,
              let questionIndex = chat.messages.lastIndex(where: { $0.role == .user }),
              questionIndex == chat.messages.count - 2 else { return nil }
        return last.id
    }

    /// Altezza minima della risposta: con la lista in fondo, la domanda resta in cima allo schermo e
    /// la risposta (con la sfera sotto) scende man mano che si scrive; quando non ci sta più, si segue il fondo.
    func minHeight(for messageId: String) -> CGFloat? {
        guard messageId == turnReplyID else { return nil }
        // padding verticale della lista (14 + 14), spaziature (16 + 16) e il segnaposto "bottom" (1).
        return max(0, visibleHeight - turnQuestionHeight - 61)
    }

    func messageHeightChanged(_ messageId: String, height: CGFloat) {
        if messageId == turnQuestionID { turnQuestionHeight = height }
    }

    // MARK: - Actions

    /// Nella lingua dell'app; si richiedono quando la chat diventa pronta (accesso, stabilimento).
    func loadSuggestions() async {
        guard backend.isReady else { suggestions = []; return }
        suggestions = Array(await backend.suggestions().prefix(4))
    }

    func sendSuggestion(_ suggestion: String) {
        chat.send(suggestion)
    }

    func retryFailedTurn() {
        guard let failed = failedTurn else { return }
        chat.regenerate(failed.id)
    }

    func dismissError() {
        chat.lastError = nil
    }

    func dismissNotice() {
        chat.notice = nil
    }

    func expandQuestion() {
        questionCollapsed = false
    }

    func expandLearning() {
        learningCollapsed = false
    }

    /// Tornando alla chat con una domanda già annunciata (o mai vista) la si mostra subito, senza avviso.
    func showCurrentLearning() {
        learningShownId = chat.activeLearning?.messageId
    }

    /// Riaperta dal chip sotto la risposta: compare subito, aperta.
    func revealLearning() {
        learningShownId = chat.activeLearning?.messageId
        learningCollapsed = false
    }

    /// Una domanda di Real-time Learning nuova: l'avviso esce dalla Dynamic Island e chiede se rispondere.
    /// Solo con "Rispondi" (o un tocco sul testo) la domanda compare in fondo; "Non ora", o nessuna scelta,
    /// la lascia sotto la risposta, a un tocco dal chip. Riaperta dal chip invece compare subito.
    func announceLearning(_ messageId: String?) {
        guard let messageId, let (_, request, manual) = chat.activeLearning else { return }
        learningCollapsed = false
        if manual || learningShownId == messageId {
            learningShownId = messageId
            return
        }
        let alert = AriaIsland.Alert(title: String(localized: "Real-time Learning"),
                                     message: request.question,
                                     systemImage: AriaLearningStyle.symbol,
                                     tint: AriaLearningStyle.tint,
                                     actions: .init(accept: String(localized: "Answer"),
                                                    decline: String(localized: "Not now")))
        AriaIsland.shared.present(alert) { [weak self] accepted in
            // Nel frattempo può essere partito un turno nuovo: la domanda allora non c'è più.
            guard let self, chat.activeLearning?.messageId == messageId else { return }
            if accepted {
                learningShownId = messageId
            } else {
                chat.declineLearning(messageId)
            }
        }
    }
}
