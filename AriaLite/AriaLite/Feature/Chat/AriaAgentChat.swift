//
//  AriaAgentChat.swift
//  AriaLite
//
//  Una conversazione con Aria, come la chat della web app: turni in streaming,
//  chiamate dirette ai tool, pause di approvazione, domande guidate,
//  checklist di procedura, feedback, storico e closeout.
//

import Foundation
import Observation

@Observable
final class AriaAgentChat {
    private(set) var sessionId: String
    private(set) var messages: [AriaAgentMessage] = []
    private(set) var isStreaming = false
    private(set) var isLoadingHistory = false
    private(set) var suggestions: [String] = []
    var lastError: String?
    /// Messaggio di esito (es. "Grazie, Aria ha imparato qualcosa").
    var notice: String?

    var style: AriaChatStyle {
        didSet { UserDefaults.standard.set(style.rawValue, forKey: Self.styleKey) }
    }
    var webSearch = false
    /// Foto e file aggiunti dal "+" del composer (solo interfaccia, come sulla web: vedi AriaContextItem).
    var contextItems: [AriaContextItem] = []

    /// Task spuntati, per messaggio: "<messageId>:<taskId>".
    private(set) var checkedTasks: Set<String> = []
    /// Segnalazioni sui task (unclear / modify / failed), per messaggio e task.
    private(set) var taskMarks: [String: String] = [:]
    private(set) var answeredElicitations: Set<String> = []
    /// Closeout proposto dalla review di fine sessione, da mostrare in un foglio.
    var pendingCloseout: AriaCloseoutChoice?
    /// Cosa ha imparato Aria dall'ultima risposta al Real-time Learning (o il salvataggio in corso).
    private(set) var learningOutcome: AriaLearningOutcome?
    /// Domanda di Real-time Learning riaperta a mano dal chip di un messaggio.
    private(set) var openedLearningId: String?
    /// Domande di Real-time Learning rimandate dalla Dynamic Island: non si propongono più da sole,
    /// restano sotto la risposta (chip "Aria non è sicura").
    private(set) var declinedLearning: Set<String> = []
    /// Cresce a ogni tocco sul chip: la vista riapre il pannello anche se era ridotto a pillola.
    private(set) var learningReveal = 0

    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private let backend: AriaBackend
    /// Contesto locale (work order / step in manutenzione): viaggia col primo turno.
    @ObservationIgnored private let context: String?
    @ObservationIgnored private var didSendContext = false
    /// Tiene la sessione tra un avvio e l'altro (solo la chat principale).
    @ObservationIgnored private let remembersSession: Bool

    private static let styleKey = "aria.chat.style"
    private static let currentSessionKey = "aria.chat.current_session"

    init(backend: AriaBackend, context: String? = nil, remembersSession: Bool = false) {
        self.backend = backend
        self.context = context
        self.remembersSession = remembersSession
        style = UserDefaults.standard.string(forKey: Self.styleKey).flatMap(AriaChatStyle.init(rawValue:)) ?? .auto
        sessionId = (remembersSession ? UserDefaults.standard.string(forKey: Self.currentSessionKey) : nil) ?? AriaNanoID.make()
    }

    private var api: AriaChatAPI { AriaChatAPI(api: backend.api) }

    /// Riprende la conversazione salvata all'avvio (se c'era).
    var hasRememberedSession: Bool {
        remembersSession && UserDefaults.standard.string(forKey: Self.currentSessionKey) == sessionId
    }

    /// La pausa ancora da decidere: blocca il composer finché l'operatore non risponde.
    var pendingInterrupt: AriaInterrupt? {
        messages.last(where: { $0.role == .assistant })?.interrupt
    }

    /// Domanda guidata attiva: la più recente, a turno finito e non ancora risposta.
    var activeElicitation: (messageId: String, elicitation: AriaElicitation)? {
        guard !isStreaming, let last = messages.last, last.role == .assistant, last.finished,
              last.interrupt == nil, let question = last.elicitation,
              !answeredElicitations.contains(question.id) else { return nil }
        return (last.id, question)
    }

    /// Domanda del Real-time Learning da porre (resolveActiveValidationRequest della web): quella riaperta
    /// dal chip, altrimenti quella dell'ultima risposta, finita e non ancora risposta. Una risposta ricaricata
    /// dallo storico non la ripropone da sola: resta a un tocco dal suo chip.
    var activeLearning: (messageId: String, request: AriaValidationRequest, manual: Bool)? {
        guard !isStreaming, learningOutcome == nil else { return nil }
        if let id = openedLearningId, let message = messages.first(where: { $0.id == id }),
           let request = message.validationRequest, canAnswerLearning(message) {
            return (id, request, true)
        }
        guard let last = messages.last(where: { $0.role == .assistant }), last.finished, last.interrupt == nil,
              !last.isHydrated, !declinedLearning.contains(last.id),
              let request = last.validationRequest, canAnswerLearning(last) else { return nil }
        return (last.id, request, false)
    }

    /// Il chip "Aria non è sicura" sotto una risposta: finché la domanda non ha avuto risposta.
    func canAnswerLearning(_ message: AriaAgentMessage) -> Bool {
        message.finished && message.validationRequest != nil
            && !answeredElicitations.contains("validation-\(message.id)")
            && learningOutcome?.id != "validation-\(message.id)"
    }

    /// La checklist che arriva nella stessa risposta della domanda: finché non è tutta spuntata
    /// la domanda (di solito "hai fatto tutto?") non si può ancora rispondere.
    var blockingTaskList: (messageId: String, list: AriaTaskList)? {
        guard let (messageId, _) = activeElicitation, let latest = latestTaskList, latest.messageId == messageId,
              latest.list.tasks.contains(where: { !isTaskChecked($0, in: messageId) }) else { return nil }
        return latest
    }

    /// Gli step di procedura della sessione, dal più recente (il "Task & Event Rail" della web):
    /// per ogni step solo l'ultima revisione, che è quella su cui si spunta.
    var sessionTaskLists: [(messageId: String, list: AriaTaskList)] {
        var seen = Set<String>()
        var result: [(messageId: String, list: AriaTaskList)] = []
        for message in messages.reversed() {
            guard let list = message.taskList, seen.insert("\(list.agent ?? ""):\(list.stepNumber)").inserted else { continue }
            result.append((message.id, list))
        }
        return result
    }

    /// Checklist più recente (per il contesto nelle istruzioni e il pulsante "Fine procedura").
    var latestTaskList: (messageId: String, list: AriaTaskList)? {
        for message in messages.reversed() {
            if let list = message.taskList { return (message.id, list) }
        }
        return nil
    }

    // MARK: - Invio

    /// Nuovo turno. `label` è il testo mostrato quando si chiama un tool diretto.
    func send(_ text: String, toolCall: AriaToolCallRequest? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isStreaming, pendingInterrupt == nil, !trimmed.isEmpty || toolCall != nil else { return }
        // Un turno nuovo chiude la card "Aria ha imparato": la prossima risposta può avere la sua domanda.
        dismissLearningOutcome()
        openedLearningId = nil

        var input = trimmed
        if let context, !didSendContext, toolCall == nil {
            input = "\(context)\n---\n\(trimmed)"
        }
        messages.append(.user(trimmed))
        let reply = AriaAgentMessage.pendingAssistant()
        messages.append(reply)
        rememberSession()

        let sessionId = self.sessionId
        let model = backend.api.config.model
        // Una chiamata diretta a un tool non porta modello, stile o istruzioni (sendQuick della web).
        let style = toolCall == nil ? self.style.rawValue : AriaChatStyle.auto.rawValue
        let instructions = toolCall == nil
            ? AriaInstructions.build(webSearch: webSearch, taskContext: taskContextSummary())
            : nil
        run(into: reply.id, onSent: { [weak self] in
            if toolCall == nil { self?.didSendContext = true }
        }) { plantId, ctx in
            AriaResponsesRequest(input: input, plantId: plantId, sessionId: sessionId, companyId: ctx.companyId,
                                 model: toolCall == nil ? model : nil, style: style, locale: ctx.locale,
                                 instructions: instructions, toolCall: toolCall)
        }
    }

    /// Chiamata diretta a un tool "safe" (es. /diag). Quelli rischiosi passano da interrupt.
    func sendQuick(label: String, tool: String, args: [String: AriaJSON]) {
        send(label, toolCall: AriaToolCallRequest(toolName: tool, args: args))
    }

    /// Risponde alla pausa: la continuazione arriva nello stesso messaggio.
    func resume(_ decision: AriaResumeDecision) {
        guard !isStreaming,
              let index = messages.lastIndex(where: { $0.role == .assistant }),
              let interrupt = messages[index].interrupt else { return }
        messages[index].prepareForResume(decision.outcome)

        let messageId = messages[index].id
        let payload = decision.payload(for: interrupt)
        let sessionId = self.sessionId
        run(into: messageId, restoreOnFailure: interrupt, onSent: {}) { plantId, ctx in
            AriaResponsesRequest(input: "", plantId: plantId, sessionId: sessionId, companyId: ctx.companyId,
                                 resume: payload)
        }
    }

    /// Ferma la risposta. Non è un errore: il messaggio resta com'è, finito.
    func stop() {
        streamTask?.cancel()
    }

    /// Rigenera: rimanda la domanda precedente come nuovo turno (come la web).
    func regenerate(_ messageId: String) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }),
              let question = messages[..<index].last(where: { $0.role == .user })?.text else { return }
        send(question)
    }

    // MARK: - Nuova conversazione / storico

    func newConversation() {
        stop()
        sessionId = AriaNanoID.make()
        messages = []
        contextItems = []
        checkedTasks = []
        taskMarks = [:]
        answeredElicitations = []
        learningOutcome = nil
        openedLearningId = nil
        declinedLearning = []
        didSendContext = false
        lastError = nil
        if remembersSession { UserDefaults.standard.removeObject(forKey: Self.currentSessionKey) }
    }

    /// Apre una conversazione salvata: messaggi e, se c'è, la pausa in attesa.
    /// `forgetIfMissing`: una sessione che il server non conosce più (404) si dimentica senza errore.
    func open(sessionId: String, forgetIfMissing: Bool = false) async {
        stop()
        self.sessionId = sessionId
        messages = []
        contextItems = []
        checkedTasks = []
        taskMarks = [:]
        answeredElicitations = []
        learningOutcome = nil
        openedLearningId = nil
        declinedLearning = []
        didSendContext = true
        lastError = nil
        isLoadingHistory = true
        defer { isLoadingHistory = false }
        do {
            var restored = try await api.messages(sessionId: sessionId).map(AriaAgentMessage.init(persisted:))
            // Le domande già superate da un turno successivo non vanno riproposte.
            for (i, message) in restored.enumerated() where i < restored.count - 1 {
                if let id = message.elicitation?.id { answeredElicitations.insert(id) }
            }
            if let pause = await api.pendingInterrupt(sessionId: sessionId) {
                if let i = restored.lastIndex(where: { $0.role == .assistant }) {
                    restored[i].interrupt = pause
                    restored[i].finished = true
                } else {
                    var synthetic = AriaAgentMessage(id: "pending-\(pause.interruptId)", role: .assistant)
                    synthetic.interrupt = pause
                    restored.append(synthetic)
                }
            }
            messages = restored
            rememberSession()
        } catch AriaError.http(status: 404, _) where forgetIfMissing {
            newConversation()
        } catch {
            handle(error)
        }
    }

    /// Riprende l'ultima conversazione all'avvio, se l'app ne ricorda una.
    func restoreIfNeeded() async {
        guard hasRememberedSession, messages.isEmpty, !isLoadingHistory else { return }
        await open(sessionId: sessionId, forgetIfMissing: true)
    }

    private func rememberSession() {
        guard remembersSession else { return }
        UserDefaults.standard.set(sessionId, forKey: Self.currentSessionKey)
    }

    // MARK: - Suggerimenti

    /// Server + generici, mescolati, senza doppioni, al massimo 6 (composeSuggestions della web).
    func loadSuggestions() async {
        let generic = AriaChatCopy.genericSuggestions.shuffled()
        suggestions = Array(generic.prefix(6))
        guard let plantId = backend.activePlantId else { return }
        let server = await api.suggestions(plantId: plantId, locale: backend.api.context.locale).shuffled()
        var seen = Set<String>()
        suggestions = Array((server + generic).filter { seen.insert($0.lowercased()).inserted }.prefix(6))
    }

    // MARK: - Feedback

    func vote(_ messageId: String, _ vote: AriaAgentMessage.Vote, note: String? = nil) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        let previous = messages[index].vote
        // Stesso pollice di nuovo = ritiro (aggiornamento ottimistico, poi decide il server).
        messages[index].vote = previous == vote && note == nil ? nil : vote
        let answer = messages[index].displayText
        let question = messages[..<index].last(where: { $0.role == .user })?.text
        let sessionId = self.sessionId
        Task {
            do {
                let result = try await api.answerFeedback(sessionId: sessionId, vote: vote.rawValue, messageId: messageId,
                                                          note: note, answer: answer, question: question)
                update(messageId) { $0.vote = result.vote.flatMap(AriaAgentMessage.Vote.init(rawValue:)) }
                if result.learned == true { notice = String(localized: "Thanks — Aria learned from your feedback.") }
            } catch {
                update(messageId) { $0.vote = previous }
                handle(error)
            }
        }
    }

    func confirmMemory(_ proposal: AriaMemoryProposal, in messageId: String, accept: Bool) {
        guard let companyId = backend.activeCompanyId else { return }
        update(messageId) { $0.memoryProposals.removeAll { $0.factId == proposal.factId } }
        Task {
            do {
                try await api.confirmMemory(companyId: companyId, factId: proposal.factId, accept: accept)
                if accept { notice = String(localized: "Saved to Aria's knowledge.") }
            } catch {
                update(messageId) { $0.memoryProposals.append(proposal) }
                handle(error)
            }
        }
    }

    // MARK: - Procedura

    func isTaskChecked(_ task: AriaTaskList.Task, in messageId: String) -> Bool {
        checkedTasks.contains("\(messageId):\(task.id)")
    }

    func toggleTask(_ task: AriaTaskList.Task, in messageId: String) {
        let key = "\(messageId):\(task.id)"
        if checkedTasks.contains(key) { checkedTasks.remove(key) } else { checkedTasks.insert(key) }
    }

    func taskMark(_ task: AriaTaskList.Task, in messageId: String) -> String? {
        taskMarks["\(messageId):\(task.id)"]
    }

    /// Chiede aiuto su un task: messaggio in inglese esatto (lo riconosce il backend) + segnale di feedback.
    func assist(_ action: AriaStepAssist, task: AriaTaskList.Task, list: AriaTaskList, in messageId: String, custom: String? = nil) {
        let head = "\(list.label), task \(task.index) (\"\(task.text)\")"
        let message = switch action {
        case .unclear: "\(head): I don't understand this step. Explain it in more detail before we continue."
        case .modify: "\(head): I need to change how this is done. Propose an adjusted version of this step."
        case .failed: "\(head): this step FAILED. Do not move on to the next step — help me work out what went wrong and give me a corrected version of this step."
        case .ask: "\(head): \(custom ?? "")"
        }
        if action != .ask {
            checkedTasks.remove("\(messageId):\(task.id)")
            taskMarks["\(messageId):\(task.id)"] = action.rawValue
        }
        let sessionId = self.sessionId
        let api = self.api
        Task { await api.stepFeedback(sessionId: sessionId, action: action == .ask ? "custom" : action.rawValue,
                                      taskList: list, task: task.text) }
        send(message)
    }

    func endProcedure() {
        send("End the procedure")
    }

    /// `Step 2 "Title": completed [1,3], pending [2].` (buildTaskContextSummary della web).
    private func taskContextSummary() -> String? {
        guard let (messageId, list) = latestTaskList else { return nil }
        var completed: [Int] = []
        var pending: [Int] = []
        for task in list.tasks {
            if isTaskChecked(task, in: messageId) { completed.append(task.index) } else { pending.append(task.index) }
        }
        func format(_ indices: [Int]) -> String { indices.isEmpty ? "none" : indices.map(String.init).joined(separator: ",") }
        let title = list.stepTitle.replacingOccurrences(of: "\"", with: "'")
        return "\(list.label) \"\(title)\": completed [\(format(completed))], pending [\(format(pending))]."
    }

    // MARK: - Domande guidate

    /// Invio delle risposte: turno di chat, oppure review + closeout per quella di fine sessione.
    func answer(_ elicitation: AriaElicitation, text: String, details: [AriaElicitationAnswer]) {
        answeredElicitations.insert(elicitation.id)
        let sessionId = self.sessionId
        let api = self.api

        if elicitation.submit == "review" {
            Task {
                if let review = AriaReviewPayload(details) {
                    do {
                        try await api.review(sessionId: sessionId, outcome: review.outcome, rating: review.rating, issues: review.issues)
                        notice = String(localized: "Review saved.")
                    } catch {
                        lastError = String(localized: "Could not save the review.")
                    }
                }
                if let choice = AriaCloseoutChoice(details) { pendingCloseout = choice }
            }
            return
        }

        let learning = details.filter { $0.file == "learning" }
        Task {
            if !learning.isEmpty { await api.learning(sessionId: sessionId, answers: learning) }
            if !text.isEmpty { send(text) }
        }
    }

    // MARK: - Real-time Learning

    /// "Non ora" dalla Dynamic Island: la domanda non si apre, resta a un tocco dal chip della risposta.
    func declineLearning(_ messageId: String) {
        declinedLearning.insert(messageId)
    }

    /// Riapre dal chip la domanda di una risposta precedente.
    func openLearning(_ messageId: String) {
        guard let message = messages.first(where: { $0.id == messageId }), canAnswerLearning(message) else { return }
        dismissLearningOutcome()
        openedLearningId = messageId
        learningReveal += 1
    }

    /// Risposta al Real-time Learning: chiarisce un dubbio e diventa conoscenza dello stabilimento.
    /// Non entra nella conversazione (niente turno, niente risposta), così la procedura non si interrompe.
    /// Segnata come risposta solo a salvataggio riuscito: se fallisce, la domanda torna per riprovare.
    func answerLearning(messageId: String, request: AriaValidationRequest, feedback: String) {
        let id = "validation-\(messageId)"
        guard let message = messages.first(where: { $0.id == messageId }) else { return }
        guard let companyId = backend.activeCompanyId, let plantId = backend.activePlantId else {
            lastError = String(localized: "Select a plant before answering — this is saved to the plant's knowledge.")
            return
        }
        let feedback = feedback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !feedback.isEmpty else { return }
        let outcome = AriaLearningOutcome(id: id, question: request.question, answer: message.text)
        learningOutcome = outcome
        let sessionId = self.sessionId
        let api = self.api
        Task {
            do {
                let response = try await api.submitValidation(companyId: companyId, plantId: plantId, sessionId: sessionId,
                                                              question: request.question, answer: message.text,
                                                              feedback: feedback)
                answeredElicitations.insert(id)
                if openedLearningId == messageId { openedLearningId = nil }
                // Nel frattempo è partito un turno nuovo: la card non serve più.
                guard learningOutcome?.id == id else { return }
                learningOutcome?.response = response
            } catch {
                if learningOutcome?.id == id { learningOutcome = nil }
                lastError = String(localized: "Could not save to Aria's learned knowledge.")
                backend.handle(error)
            }
        }
    }

    /// "Non ora" sulla domanda riaperta dal chip: torna quella automatica (se c'è).
    func closeOpenedLearning() {
        openedLearningId = nil
    }

    func dismissLearningOutcome() {
        guard learningOutcome?.isSaving != true else { return }
        learningOutcome = nil
    }

    /// "Notifica": manda i fatti ancora in proposta agli amministratori perché li validino.
    /// Restano in attesa: li approva solo un amministratore.
    func notifyLearning(_ factIds: [String]) async -> Bool {
        guard let companyId = backend.activeCompanyId, !factIds.isEmpty else { return false }
        do {
            for factId in factIds {
                try await api.confirmMemory(companyId: companyId, factId: factId, accept: true)
            }
            notice = String(localized: "Sent for validation — an admin will review it.")
            return true
        } catch {
            lastError = String(localized: "Could not send it for validation.")
            return false
        }
    }

    // MARK: - Closeout

    func closeout(_ request: AriaCloseoutRequest) async throws -> AriaCloseoutResult {
        guard let companyId = backend.activeCompanyId else { throw AriaError.missingCompany }
        return try await api.closeout(companyId: companyId, sessionId: sessionId, request)
    }

    /// Dopo l'archiviazione, un messaggio locale con l'esito (come la web).
    func appendCloseoutSummary(_ result: AriaCloseoutResult) {
        var lines: [String] = []
        if let title = result.workOrderTitle ?? result.aria?.title { lines.append("**\(title)**") }
        if let aria = result.aria, aria.status == "created" {
            let id = aria.id?.value ?? result.workOrderId ?? ""
            lines.append("ARIA: [WO \(id)](/work-orders?selected=\(id))" + (result.workOrderStatus.map { " · `\($0)`" } ?? ""))
        }
        if let mx = result.maintainx {
            switch mx.status {
            case "created": lines.append("MaintainX: " + (mx.url.map { "[\(String(localized: "Open in MaintainX"))](\($0))" } ?? "✓"))
            case "failed": lines.append("MaintainX: \(mx.error ?? String(localized: "not written"))")
            default: break
            }
        }
        guard !lines.isEmpty else { return }
        messages.append(AriaAgentMessage(id: UUID().uuidString, role: .assistant, text: lines.joined(separator: "\n")))
    }

    // MARK: - Stream

    private func run(into messageId: String, restoreOnFailure interrupt: AriaInterrupt? = nil,
                     onSent: @escaping () -> Void,
                     makeRequest: @escaping @Sendable (_ plantId: String, _ ctx: AriaContext.Snapshot) -> AriaResponsesRequest) {
        isStreaming = true
        lastError = nil
        let api = backend.api
        streamTask = Task(name: "aria.chat.turn") {
            let playback = StreamPlayback()
            let player = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: StreamPlayback.tick)
                    show(playback.tick(), in: messageId)
                }
            }
            defer { player.cancel() }
            do {
                let ctx = await api.context.snapshot()
                guard let plantId = ctx.plantId, !plantId.isEmpty else { throw AriaError.missingPlant }
                onSent()
                for try await event in api.stream(makeRequest(plantId, ctx)) {
                    show(playback.push(event), in: messageId)
                }
                // La rete ha finito, ma un pezzo lungo può essere ancora a metà: esce fino in fondo.
                player.cancel()
                while !playback.isEmpty {
                    show(playback.tick(), in: messageId)
                    if !playback.isEmpty { try await Task.sleep(for: StreamPlayback.tick) }
                }
                update(messageId) { $0.finished = true }
            } catch {
                // Fermata o errore: quello che è già arrivato si mostra subito, tutto.
                show(playback.drain(), in: messageId)
                let cancelled = Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled
                update(messageId) { m in
                    m.finished = true
                    if cancelled { return }
                    m.error = error.localizedDescription
                    // Errore di rete durante una ripresa: la pausa torna, così si può riprovare.
                    if let interrupt {
                        m.interrupt = interrupt
                        m.interruptOutcome = nil
                    }
                }
                if !cancelled { handle(error) }
            }
            isStreaming = false
            streamTask = nil
        }
    }

    /// Quello che esce in un tick si applica insieme: un solo ridisegno.
    private func show(_ events: [AriaStreamEvent], in messageId: String) {
        guard !events.isEmpty else { return }
        update(messageId) { m in
            for event in events { m.apply(event) }
        }
        for event in events {
            if case .textDelta(let text) = event {
                AriaStreamTrace.event("apply", "textDelta", bytes: text.utf8.count)
            } else {
                AriaStreamTrace.event("apply", String(describing: event).prefix(while: { $0 != "(" }).description)
            }
        }
    }

    private func update(_ id: String, _ mutate: (inout AriaAgentMessage) -> Void) {
        guard let i = messages.firstIndex(where: { $0.id == id }) else { return }
        mutate(&messages[i])
    }

    private func handle(_ error: any Error) {
        lastError = error.localizedDescription
        backend.handle(error)
    }
}

/// Lo stream tra la rete e lo schermo. Il testo esce a ogni tick da 50 ms (in una chat lunga ridisegnare
/// a ogni token faceva restare indietro il testo anche di mezzo secondo) e ogni altro evento esce dopo
/// il testo arrivato prima di lui.
///
/// Un pezzo lungo arrivato in un colpo solo esce a fette, una per tick, e si vede scrivere come il resto.
/// È il gate di sicurezza: il backend non lo manda token per token (la parola "SAFE" del verdetto non deve
/// arrivare all'operatore) ma tutto insieme, quando il modello ha finito. Lo stesso per le tabelle di chiusura.
private final class StreamPlayback {
    static let tick: Duration = .milliseconds(50)
    /// Un pezzo più lungo di così non è un token dello stream.
    private static let longPiece = 120
    /// Caratteri per fetta: circa 400 al secondo, come uno stream vero...
    private static let sliceSize = 20
    /// ...ma un pezzo lungo non ci mette più di 2 secondi.
    private static let maxSlices = 40

    private enum Item {
        /// Esce al prossimo tick, con tutto quello che è pronto.
        case ready(AriaStreamEvent)
        /// Una fetta di un pezzo lungo: una per tick.
        case slice(String)
    }

    private var queue: [Item] = []
    private var pendingSlices = 0

    var isEmpty: Bool { queue.isEmpty }

    /// Mette in coda un evento e restituisce quelli da mostrare subito.
    func push(_ event: AriaStreamEvent) -> [AriaStreamEvent] {
        guard case .textDelta(let text) = event else {
            // Tool, card, testo finale: senza un pezzo lungo in uscita si mostrano subito, dopo il testo già ricevuto.
            guard pendingSlices > 0 else { return drain() + [event] }
            queue.append(.ready(event))
            return []
        }
        if text.count > Self.longPiece {
            enqueueSlices(of: text)
        } else if case .ready(.textDelta(let previous))? = queue.last {
            queue[queue.count - 1] = .ready(.textDelta(previous + text))
        } else {
            queue.append(.ready(event))
        }
        return []
    }

    /// Quello che è pronto, fino alla prossima fetta compresa.
    func tick() -> [AriaStreamEvent] {
        var out: [AriaStreamEvent] = []
        while !queue.isEmpty {
            switch queue.removeFirst() {
            case .ready(let event):
                out.append(event)
            case .slice(let text):
                pendingSlices -= 1
                out.append(.textDelta(text))
                return out
            }
        }
        return out
    }

    /// Tutto quello che resta, subito.
    func drain() -> [AriaStreamEvent] {
        defer {
            queue = []
            pendingSlices = 0
        }
        return queue.map {
            switch $0 {
            case .ready(let event): event
            case .slice(let text): .textDelta(text)
            }
        }
    }

    /// Fette che finiscono a fine parola (al massimo una fetta più in là, per "intercettazione" e simili),
    /// così non si spezzano le parole e non superano mai `maxSlices`. Il blocco ```elicit in fondo non si vede
    /// (diventa il pannello di domande) ed esce in una volta: a fette la risposta sembrerebbe già finita
    /// e il pannello tarderebbe.
    private func enqueueSlices(of text: String) {
        let hidden = text.range(of: #"```[ \t]*elicit"#, options: [.regularExpression, .caseInsensitive])?.lowerBound
            ?? text.endIndex
        let visible = text[..<hidden]
        let size = max(Self.sliceSize, (visible.count + Self.maxSlices - 1) / Self.maxSlices)
        var start = visible.startIndex
        while start < visible.endIndex {
            var end = visible.index(start, offsetBy: size, limitedBy: visible.endIndex) ?? visible.endIndex
            if end < visible.endIndex, !visible[visible.index(before: end)].isWhitespace {
                let limit = visible.index(end, offsetBy: size, limitedBy: visible.endIndex) ?? visible.endIndex
                if let space = visible[end..<limit].firstIndex(where: \.isWhitespace) {
                    end = visible.index(after: space)
                }
            }
            queue.append(.slice(String(visible[start..<end])))
            pendingSlices += 1
            start = end
        }
        if hidden < text.endIndex {
            queue.append(.ready(.textDelta(String(text[hidden...]))))
        }
    }
}

enum AriaStepAssist: String, CaseIterable {
    case unclear, modify, failed, ask
}

/// Review di fine sessione (toReviewPayload della web).
struct AriaReviewPayload {
    let outcome: String
    let rating: Int?
    let issues: String?

    init?(_ answers: [AriaElicitationAnswer]) {
        func byKey(_ key: String) -> AriaElicitationAnswer? { answers.first { $0.key == key } }
        guard let value = byKey("outcome")?.value, ["resolved", "partial", "unresolved"].contains(value) else { return nil }
        outcome = value
        let rating = byKey("rating")?.value.flatMap { Int($0) }
        self.rating = rating.flatMap { (1...5).contains($0) ? $0 : nil }
        if let issues = byKey("issues") {
            let text = issues.text.trimmingCharacters(in: .whitespacesAndNewlines)
            self.issues = !text.isEmpty && issues.value != "none" ? text : issues.value
        } else {
            issues = nil
        }
    }
}

/// Come archiviare l'intervento (toCloseoutChoice della web).
struct AriaCloseoutChoice: Identifiable {
    let id = UUID()
    var workOrder: Bool
    var report: Bool
    var assigneeId: String?
    var priority: String?
    var dueDate: String?

    init(workOrder: Bool, report: Bool) {
        self.workOrder = workOrder
        self.report = report
    }

    init?(_ answers: [AriaElicitationAnswer]) {
        let value = answers.first { $0.key == "closeout" }?.value
        guard value == "report_wo" || value == "report" else { return nil }
        workOrder = value == "report_wo"
        report = true
        if let assignee = answers.first(where: { $0.key == "assignee" })?.value, assignee != "none" { assigneeId = assignee }
        if let urgency = answers.first(where: { $0.key == "priority_due" })?.value {
            let parts = urgency.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            if let first = parts.first, !first.isEmpty { priority = first }
            if parts.count > 1, let days = Int(parts[1]),
               let due = Calendar.current.date(byAdding: .day, value: days, to: .now) {
                dueDate = due.formatted(.iso8601)
            }
        }
    }
}

/// La card che prende il posto della domanda di Real-time Learning appena risposta (LearningResult della web).
struct AriaLearningOutcome: Identifiable, Equatable {
    /// `validation-<messageId>`.
    let id: String
    let question: String
    /// La risposta di Aria che l'operatore ha validato.
    let answer: String
    /// nil finché il salvataggio è in corso.
    var response: AriaMemoryValidationResponse? = nil

    var isSaving: Bool { response == nil }
    var items: [AriaMemoryValidationResponse.Item] { response?.items ?? [] }
    var learnedSomething: Bool { items.contains { !$0.isProposed } }
}
