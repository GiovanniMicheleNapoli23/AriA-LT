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
    /// Microfono della chat vocale esistente (quando il campo è vuoto).
    let voice: AriaVoiceViewModel?
    /// Il composer ha la sua logica (bozza, dettatura, contesto): la chat lo tiene e lo consulta.
    let composer: AriaChatComposerViewModel

    // MARK: - State

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
    /// Altezza degli avvisi sopra il pannello (in orizzontale scorrono in uno spazio limitato).
    var noticesHeight: CGFloat = 0
    /// Parte visibile della lista (senza barre e pannello in basso) e altezza dell'ultima domanda:
    /// servono a tenere la domanda in cima mentre la risposta cresce sotto (come Claude).
    var visibleHeight: CGFloat = 600
    private var turnQuestionHeight: CGFloat = 0

    init(chat: AriaAgentChat, backend: AriaBackend, voice: AriaVoiceViewModel? = nil) {
        self.chat = chat
        self.backend = backend
        self.voice = voice
        composer = AriaChatComposerViewModel(chat: chat, backend: backend, voice: voice)
    }

    // MARK: - Derived

    /// Mentre l'operatore scrive la sfera della chat vuota "pensa".
    var isComposing: Bool { composer.hasText }

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

    // MARK: - Messaggi e avvisi

    var messages: [AriaAgentMessage] { chat.messages }
    var isLoadingHistory: Bool { chat.isLoadingHistory }
    var isStreaming: Bool { chat.isStreaming }
    var webURL: URL { backend.webURL }
    var notice: String? { chat.notice }
    var turnError: String? { chat.lastError }
    var turnErrorIsOffline: Bool { chat.lastErrorIsOffline }
    var activeQuestionID: String? { chat.activeElicitation?.elicitation.id }
    var hasBlockingProcedure: Bool { chat.blockingTaskList != nil }
    var isOnline: Bool { AriaNetworkMonitor.shared.isOnline }
    /// Senza stabilimento il backend non risponde: lo si chiede prima di scrivere.
    var needsPlant: Bool { backend.activePlantId == nil }
    var canRetry: Bool { failedTurn != nil }

    /// La chat con Aria non funziona offline (lavori e calendario sì): lo si dice prima che fallisca
    /// un invio, ma non due volte se l'ultimo turno è già fallito per la rete.
    var showsNetworkNotice: Bool {
        !isOnline && !(turnError != nil && turnErrorIsOffline)
    }

    var showsVoiceSession: Bool {
        guard let voice else { return false }
        return voice.isConnected || voice.isConnecting || voice.error != nil
    }

    func isLast(_ messageId: String) -> Bool {
        messageId == chat.messages.last?.id
    }

    /// La pausa in attesa (approvazione o LOTO) da mostrare nella lista quando il composer è bloccato.
    var pendingInterruptMessageID: String? {
        chat.messages.last(where: { $0.interrupt != nil })?.id
    }

    var pendingCloseout: AriaCloseoutChoice? {
        get { chat.pendingCloseout }
        set { chat.pendingCloseout = newValue }
    }

    /// Spazio per le domande: quello che resta tolte intestazione e margini, mai più della quota data.
    func optionsHeight(share: CGFloat) -> CGFloat {
        max(60, min(viewportHeight * share, viewportHeight - 90))
    }

    /// In orizzontale con la tastiera restano ~150pt: gli avvisi scorrono in un quarto della chat
    /// invece di spingere il composer sotto la barra.
    var noticesMaxHeight: CGFloat {
        min(noticesHeight, max(44, viewportHeight * 0.25))
    }

    // MARK: - Haptic

    var messageCount: Int { chat.messages.count }

    /// Esito dell'ultima pausa decisa (approvazione o LOTO).
    var lastInterruptOutcome: AriaInterruptOutcome? {
        chat.messages.last(where: { $0.role == .assistant })?.interruptOutcome
    }

    /// Turno nuovo: domanda e risposta in arrivo aggiunte insieme (lo storico caricato non conta).
    func feedbackForMessages(from old: Int, to new: Int) -> SensoryFeedback? {
        new == old + 2 && chat.isStreaming ? .impact(weight: .light) : nil
    }

    /// Aria ha finito e aspetta l'operatore: una decisione da prendere o una domanda.
    func feedbackForStreaming(was: Bool, now: Bool) -> SensoryFeedback? {
        guard was, !now, chat.lastError == nil else { return nil }
        if chat.pendingInterrupt != nil { return .warning }
        if chat.activeElicitation != nil { return .impact(weight: .medium) }
        return nil
    }

    /// La decisione sulla pausa: il LOTO confermato "pesa" più di un'approvazione.
    func feedback(for outcome: AriaInterruptOutcome?) -> SensoryFeedback? {
        guard chat.isStreaming, let outcome else { return nil }
        return switch outcome {
        case .approved, .edited: .success
        case .rejected: .impact(weight: .medium)
        case .lotoConfirmed: .impact(weight: .heavy)
        case .lotoDeclined: .warning
        }
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

    /// L'id dell'ultimo messaggio: la lista lo legge una volta per body invece di `isLast` per riga.
    var lastMessageID: String? { chat.messages.last?.id }

    /// La risposta del turno con la sua altezza minima, calcolata una volta (come `minHeight(for:)`).
    var replyMinHeight: (id: String, height: CGFloat)? {
        guard let id = turnReplyID, let height = minHeight(for: id) else { return nil }
        return (id, height)
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

    func restore() async {
        await chat.restoreIfNeeded()
    }

    func answerQuestion(_ question: AriaElicitation, text: String, details: [AriaElicitationAnswer]) {
        chat.answer(question, text: text, details: details)
    }

    func answerLearning(messageId: String, request: AriaValidationRequest, feedback: String) {
        chat.answerLearning(messageId: messageId, request: request, feedback: feedback)
    }

    func resumeLoto(_ decision: AriaResumeDecision) {
        chat.resume(decision)
    }

    /// Dall'avviso offline "Riprova" chiude anche l'avviso.
    func retryAfterOfflineError() {
        dismissError()
        retryFailedTurn()
    }

    func jumpToBottom() {
        scroll.followBottom()
    }

    func dismissNotice() {
        chat.notice = nil
    }

    func expandQuestion() {
        questionCollapsed = false
    }

    func collapseQuestion() {
        questionCollapsed = true
    }

    /// Una domanda guidata nuova si mostra aperta.
    func questionChanged() {
        questionCollapsed = false
    }

    func collapseLearning() {
        learningCollapsed = true
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
