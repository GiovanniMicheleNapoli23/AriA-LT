//
//  AriaAgentMessage.swift
//  AriaLite
//
//  Un messaggio della chat con il backend Aria e come ogni evento dello
//  stream lo modifica (porting di applyResponsesEvent della web).
//

import Foundation

struct AriaPipelineEntry: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let data: AriaJSON
}

struct AriaAgentMessage: Identifiable {
    enum Role { case user, assistant }
    enum Vote: String { case up, down }

    let id: String
    let role: Role
    var text = ""
    var reasoning = ""
    var sources: [AriaSourceRef] = []
    var toolCalls: [AriaToolCall] = []
    var artifacts: [AriaArtifact] = []
    var uiActions: [AriaUIAction] = []
    var images: [AriaImageReference] = []
    var elicitation: AriaElicitation? = nil
    var taskList: AriaTaskList? = nil
    var memoryFactsUsed: [String] = []
    var memoryLearned: [AriaMemoryLearned] = []
    var memoryProposals: [AriaMemoryProposal] = []
    /// Verdetto del gate di confidenza, con l'eventuale domanda del Real-time Learning.
    var answerConfidence: AriaAnswerConfidence? = nil
    /// `aria.validation_request` arrivato prima del verdetto: si aggancia appena arriva.
    var pendingValidationRequest: AriaValidationRequest? = nil
    var pipeline: [AriaPipelineEntry] = []
    var interrupt: AriaInterrupt? = nil
    var interruptOutcome: AriaInterruptOutcome? = nil
    var usage: AriaUsage? = nil
    var responseId: String? = nil
    var episode: Int? = nil
    var finished = true
    var error: String? = nil
    /// Solo locale: il voto dato dall'operatore.
    var vote: Vote? = nil

    static func user(_ text: String) -> AriaAgentMessage {
        AriaAgentMessage(id: UUID().uuidString, role: .user, text: text)
    }

    static func pendingAssistant() -> AriaAgentMessage {
        AriaAgentMessage(id: UUID().uuidString, role: .assistant, finished: false)
    }

    /// Testo da mostrare: il blocco ```elicit``` diventa il pannello di domande, non testo,
    /// e gli elenchi che ripetono le opzioni della domanda o i task della checklist si tolgono
    /// (stanno già nel pannello in basso).
    var displayText: String {
        let stripped = Self.stripElicitBlock(text)
        let options = elicitation.map { question in
            (question.options + (question.steps ?? []).flatMap(\.options)).flatMap { [$0.label] + [$0.description].compactMap { $0 } }
        } ?? []
        let tasks = taskList?.tasks.map(\.text) ?? []
        guard !options.isEmpty || !tasks.isEmpty else { return stripped }
        return AriaPanelDedup.strip(stripped, options: options, tasks: tasks,
                                    headings: [taskList?.stepTitle].compactMap { $0 })
    }

    /// La domanda del Real-time Learning di questa risposta (answerConfidence.validation_request della web).
    var validationRequest: AriaValidationRequest? { answerConfidence?.validationRequest }

    /// Ricostruito dallo storico: gli id `db-` non coincidono con quelli del turno dal vivo.
    var isHydrated: Bool { id.hasPrefix("db-") }

    /// Non c'è ancora niente da mostrare: al suo posto l'indicatore di digitazione.
    var isAwaitingContent: Bool {
        role == .assistant && !finished && displayText.isEmpty && toolCalls.isEmpty
            && artifacts.isEmpty && reasoning.isEmpty
    }

    // MARK: - Eventi

    mutating func apply(_ event: AriaStreamEvent) {
        switch event {
        case .created(let id):
            responseId = id
        case .textDelta(let delta):
            text += delta
        case .textDone(let final):
            // Copia finale ripulita dal server: sostituisce quella accumulata (come la web).
            if !final.isEmpty { text = final }
        case .reasoningDelta(let delta):
            reasoning += delta
        case .completed(let status, let usage):
            finished = true
            if let usage { self.usage = usage }
            if status == "failed" { error = String(localized: "The response failed.") }
        case .failed(let message):
            finished = true
            error = message
        case .toolCall(let call):
            if let i = toolCalls.firstIndex(where: { $0.id == call.id }) { toolCalls[i] = call } else { toolCalls.append(call) }
        case .artifact(let artifact):
            if !artifacts.contains(where: { $0.id == artifact.id }) { artifacts.append(artifact) }
        case .uiAction(let action):
            if !uiActions.contains(where: { $0.id == action.id }) { uiActions.append(action) }
        case .imageReference(let image):
            if !images.contains(image) { images.append(image) }
        case .elicitation(let question):
            if question.isUsable { elicitation = question }
        case .sources(let list):
            var seen = Set<String>()
            sources = list.filter { seen.insert($0.url ?? $0.title).inserted }
        case .memoryContext(let facts, let raw):
            memoryFactsUsed = facts
            pipeline.append(AriaPipelineEntry(name: "aria.memory_context_loaded", data: raw))
        case .memoryLearned(let items):
            memoryLearned += items
        case .memoryProposal(let proposal):
            if !memoryProposals.contains(where: { $0.factId == proposal.factId }) { memoryProposals.append(proposal) }
        case .answerConfidence(var verdict):
            // Si unisce, non si sostituisce: dev manda il verdetto due volte (con la domanda, poi senza)
            // e val-dev-2 manda la domanda in un frame a parte. La si tiene solo se serve ancora validare.
            if verdict.validationRequest == nil, verdict.needsValidation {
                verdict.validationRequest = answerConfidence?.validationRequest ?? pendingValidationRequest
            }
            answerConfidence = verdict
            pendingValidationRequest = nil
        case .validationRequest(let request):
            if answerConfidence == nil { pendingValidationRequest = request } else { answerConfidence?.validationRequest = request }
        case .diagnosticState(let number):
            if let number { episode = number }
        case .interrupt(let pause):
            interrupt = pause
            interruptOutcome = nil
        case .taskList(let list):
            taskList = list
        case .pipeline(let name, let data):
            pipeline.append(AriaPipelineEntry(name: name, data: data))
        case .ignored:
            break
        }
    }

    /// Prima di riprendere dopo una pausa (prepareForResume della web).
    mutating func prepareForResume(_ outcome: AriaInterruptOutcome) {
        interrupt = nil
        interruptOutcome = outcome
        finished = false
        error = nil
        if !text.isEmpty { text += "\n\n" }
    }

    // MARK: - Storico

    /// Ricostruisce un messaggio salvato (persistedToResponsesMessage della web).
    init(persisted row: AriaPersistedMessage) {
        id = "db-" + (row.id?.value ?? UUID().uuidString)
        role = row.role == "user" ? .user : .assistant
        text = row.text ?? ""
        reasoning = row.reasoning ?? ""
        sources = row.sources ?? []
        toolCalls = row.toolCalls?.items ?? []
        artifacts = row.artifacts?.items ?? []
        uiActions = row.uiActions?.items ?? []
        images = row.imageReferences?.items ?? []
        usage = row.usage
        responseId = row.responseId
        episode = row.episode
        for entry in row.pipeline ?? [] {
            let name = entry["type"]?.stringValue ?? ""
            switch name {
            case "aria.elicitation":
                if let question = try? entry.decoded(as: AriaElicitation.self), question.isUsable { elicitation = question }
            case "aria.memory_context_loaded":
                if case .array(let facts)? = entry["facts"] { memoryFactsUsed = facts.compactMap(\.stringValue) }
                pipeline.append(AriaPipelineEntry(name: name, data: entry))
            case "aria.task_list":
                if let list = try? entry.decoded(as: AriaTaskList.self) { taskList = list }
            default:
                if AriaStreamEvent.pipelineEvents.contains(name) { pipeline.append(AriaPipelineEntry(name: name, data: entry)) }
            }
        }
    }

    init(id: String, role: Role, text: String = "", finished: Bool = true) {
        self.id = id
        self.role = role
        self.text = text
        self.finished = finished
    }

    // MARK: - Testo

    /// stripElicitBlock della web: toglie i blocchi completi e quello ancora aperto durante lo streaming.
    static func stripElicitBlock(_ text: String) -> String {
        guard text.localizedCaseInsensitiveContains("elicit") else { return text }
        var out = text.replacingOccurrences(of: #"```[ \t]*elicit[ \t]*\r?\n[\s\S]*?```"#,
                                            with: "", options: [.regularExpression, .caseInsensitive])
        out = out.replacingOccurrences(of: #"```[ \t]*elicit[ \t]*[\s\S]*$"#,
                                       with: "", options: [.regularExpression, .caseInsensitive])
        while out.last?.isWhitespace == true { out.removeLast() }
        return out
    }
}
