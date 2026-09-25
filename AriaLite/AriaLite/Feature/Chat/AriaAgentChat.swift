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

    /// Task spuntati, per messaggio: "<messageId>:<taskId>".
    private(set) var checkedTasks: Set<String> = []
    /// Segnalazioni sui task (unclear / modify / failed), per messaggio e task.
    private(set) var taskMarks: [String: String] = [:]
    private(set) var answeredElicitations: Set<String> = []
    /// Closeout proposto dalla review di fine sessione, da mostrare in un foglio.
    var pendingCloseout: AriaCloseoutChoice?

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
        checkedTasks = []
        taskMarks = [:]
        answeredElicitations = []
        didSendContext = false
        lastError = nil
        if remembersSession { UserDefaults.standard.removeObject(forKey: Self.currentSessionKey) }
    }

    /// Apre una conversazione salvata: messaggi e, se c'è, la pausa in attesa.
    func open(sessionId: String) async {
        stop()
        self.sessionId = sessionId
        messages = []
        checkedTasks = []
        taskMarks = [:]
        answeredElicitations = []
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
        } catch {
            handle(error)
        }
    }

    /// Riprende l'ultima conversazione all'avvio, se l'app ne ricorda una.
    func restoreIfNeeded() async {
        guard hasRememberedSession, messages.isEmpty, !isLoadingHistory else { return }
        await open(sessionId: sessionId)
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
            do {
                let ctx = await api.context.snapshot()
                guard let plantId = ctx.plantId, !plantId.isEmpty else { throw AriaError.missingPlant }
                onSent()
                for try await event in api.stream(makeRequest(plantId, ctx)) {
                    update(messageId) { $0.apply(event) }
                }
                update(messageId) { $0.finished = true }
            } catch {
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

    private func update(_ id: String, _ mutate: (inout AriaAgentMessage) -> Void) {
        guard let i = messages.firstIndex(where: { $0.id == id }) else { return }
        mutate(&messages[i])
    }

    private func handle(_ error: any Error) {
        lastError = error.localizedDescription
        backend.handle(error)
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
