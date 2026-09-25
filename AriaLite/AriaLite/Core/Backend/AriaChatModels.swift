//
//  AriaChatModels.swift
//  AriaLite
//
//  Contratto di POST /v1/responses (richiesta ed eventi SSE) e dei payload
//  collegati alla chat. Ricalca i tipi della web app (types/agent-stream.ts,
//  lib/ai/responses-stream.ts) così l'app si comporta come la chat web.
//

import Foundation

// MARK: - Richiesta

nonisolated struct AriaToolCallRequest: Encodable, Sendable {
    var toolName: String
    var args: [String: AriaJSON]

    enum CodingKeys: String, CodingKey {
        case toolName = "tool_name"
        case args
    }
}

nonisolated struct AriaResumePayload: Encodable, Sendable {
    var interruptId: String
    var decision: String? = nil
    var args: [String: AriaJSON]? = nil
    var confirmed: Bool? = nil

    enum CodingKeys: String, CodingKey {
        case interruptId = "interrupt_id"
        case decision, args, confirmed
    }
}

/// Risposta dell'operatore a una pausa (`aria.interrupt`).
nonisolated enum AriaResumeDecision: Sendable {
    case approve
    /// Approvazione con i parametri modificati: si manda l'oggetto args completo.
    case edit([String: AriaJSON])
    case reject
    case loto(confirmed: Bool)

    func payload(for interrupt: AriaInterrupt) -> AriaResumePayload {
        switch self {
        case .approve: AriaResumePayload(interruptId: interrupt.interruptId, decision: "approve")
        case .edit(let args): AriaResumePayload(interruptId: interrupt.interruptId, decision: "edit", args: args)
        case .reject: AriaResumePayload(interruptId: interrupt.interruptId, decision: "reject")
        case .loto(let confirmed): AriaResumePayload(interruptId: interrupt.interruptId, confirmed: confirmed)
        }
    }

    var outcome: AriaInterruptOutcome {
        switch self {
        case .approve: .approved
        case .edit: .edited
        case .reject: .rejected
        case .loto(let confirmed): confirmed ? .lotoConfirmed : .lotoDeclined
        }
    }
}

nonisolated enum AriaInterruptOutcome: Sendable, Equatable {
    case approved, edited, rejected, lotoConfirmed, lotoDeclined
}

nonisolated struct AriaResponsesRequest: Encodable, Sendable {
    nonisolated struct StreamOptions: Encodable, Sendable {
        var includeUsage = true
        enum CodingKeys: String, CodingKey { case includeUsage = "include_usage" }
    }

    /// Solo il nuovo testo: la storia la tiene il backend (legata a `session_id`).
    var input: String
    /// Obbligatorio per il backend (422 senza).
    var plantId: String
    var sessionId: String
    var companyId: String? = nil
    var stream = true
    var streamOptions = StreamOptions()
    /// Senza, niente tool call / artifact / interrupt.
    var includeMetadataEvents = true
    /// I trace servono solo al Glass Box admin della web.
    var includeTrace = false
    var model: String? = nil
    var lineId: String? = nil
    var style: String? = nil
    var locale: String? = nil
    var instructions: String? = nil
    var toolCall: AriaToolCallRequest? = nil
    var resume: AriaResumePayload? = nil

    enum CodingKeys: String, CodingKey {
        case input, stream, model, style, locale, instructions, resume
        case plantId = "plant_id"
        case sessionId = "session_id"
        case companyId = "company_id"
        case streamOptions = "stream_options"
        case includeMetadataEvents = "include_metadata_events"
        case includeTrace = "include_trace"
        case lineId = "line_id"
        case toolCall = "tool_call"
    }
}

/// Stile di risposta: stesse opzioni del menu della web.
nonisolated enum AriaChatStyle: String, CaseIterable, Sendable {
    case auto, detailed, compact
}

/// `buildInstructions` della web (lib/chat/options.ts), testo identico.
nonisolated enum AriaInstructions {
    static func build(lineId: String? = nil, webSearch: Bool, taskContext: String?) -> String {
        let scope = if let lineId {
            "You are a manufacturing assistant for production line \"\(lineId)\". Focus your answers on this specific line's metrics, status, events, and performance. If the user asks about other lines, you may still answer but note their current focus."
        } else {
            "You are a manufacturing assistant with access to all production line data. Help the user understand production metrics, line status, events, and performance across all lines."
        }
        let search = webSearch
            ? "Web search is enabled. When external information is useful, provide grounded citations in your response."
            : "Web search is disabled. Prioritize production context and available conversation data."
        let task = taskContext?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let taskPrompt = task.isEmpty ? "" : "Task progress context (from user checkboxes): \(task)"
        return [scope, search, taskPrompt].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }
}

// MARK: - Eventi

nonisolated enum AriaRiskLevel: String, AriaUnknownCaseDecodable {
    case safe, review, destructive, unknown
    static var unknownCase: Self { .unknown }
}

nonisolated enum AriaToolCallStatus: String, AriaUnknownCaseDecodable {
    case running, ok, error, proposed, rejected, unknown
    static var unknownCase: Self { .unknown }
}

nonisolated enum AriaInterruptKind: String, AriaUnknownCaseDecodable {
    case toolApproval = "tool_approval"
    case loto
    case unknown
    static var unknownCase: Self { .unknown }
}

nonisolated struct AriaToolCall: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let args: [String: AriaJSON]?
    let status: AriaToolCallStatus
    let risk: AriaRiskLevel?
    let resultPreview: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case id, name, args, status, risk, error
        case resultPreview = "result_preview"
    }
}

nonisolated struct AriaArtifact: Codable, Sendable, Identifiable, Hashable {
    nonisolated struct Source: Codable, Sendable, Hashable {
        let toolName: String
        let toolArgs: [String: AriaJSON]?
        enum CodingKeys: String, CodingKey {
            case toolName = "tool_name"
            case toolArgs = "tool_args"
        }
    }

    let id: String
    let kind: String
    let role: String?
    let data: [String: AriaJSON]
    let source: Source?

    /// Deliverable (in evidenza) o contesto: `role` vince, altrimenti decide il tipo (artifact-roles.ts).
    var isDeliverable: Bool {
        if let role { return role == "deliverable" }
        return Self.deliverableKinds.contains(kind)
    }

    private static let deliverableKinds: Set<String> = [
        "chart", "wo-card", "table", "kpi-grid", "maintenance-plan-card", "alarm-toast", "dashboard",
        "reassignment-plan", "assignment-suggestion", "triage-plan", "member-absence-plan", "team-kanban",
    ]
}

nonisolated struct AriaUIAction: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let action: String
    let to: String?
    let params: [String: AriaJSON]?
}

nonisolated struct AriaImageReference: Codable, Sendable, Identifiable, Hashable {
    let url: String
    let caption: String?
    let imageType: String?
    let pageNumber: Int?

    var id: String { url }

    enum CodingKeys: String, CodingKey {
        case url, caption
        case imageType = "image_type"
        case pageNumber = "page_number"
    }
}

nonisolated struct AriaInterrupt: Codable, Sendable, Hashable {
    let interruptId: String
    let kind: AriaInterruptKind
    let id: String?
    let name: String?
    let args: [String: AriaJSON]?
    let risk: AriaRiskLevel?
    let alarmCode: String?
    let warning: String?

    enum CodingKeys: String, CodingKey {
        case interruptId = "interrupt_id"
        case kind, id, name, args, risk, warning
        case alarmCode = "alarm_code"
    }
}

nonisolated struct AriaElicitationOption: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let label: String
    let description: String?
    let followUp: String?
    let value: String?

    enum CodingKeys: String, CodingKey {
        case id, label, description, value
        case followUp = "follow_up"
    }
}

nonisolated struct AriaElicitationStep: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let question: String
    let mode: String
    let allowCustom: Bool
    let options: [AriaElicitationOption]
    let topic: String?
    let key: String?
    let file: String?

    enum CodingKeys: String, CodingKey {
        case id, question, mode, options, topic, key, file
        case allowCustom = "allow_custom"
    }

    init(id: String, question: String, mode: String, allowCustom: Bool, options: [AriaElicitationOption],
         topic: String?, key: String? = nil, file: String? = nil) {
        self.id = id
        self.question = question
        self.mode = mode
        self.allowCustom = allowCustom
        self.options = options
        self.topic = topic
        self.key = key
        self.file = file
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        question = try c.decodeIfPresent(String.self, forKey: .question) ?? ""
        mode = try c.decodeIfPresent(String.self, forKey: .mode) ?? "single"
        allowCustom = try c.decodeIfPresent(Bool.self, forKey: .allowCustom) ?? false
        options = try c.decodeIfPresent([AriaElicitationOption].self, forKey: .options) ?? []
        topic = try c.decodeIfPresent(String.self, forKey: .topic)
        key = try c.decodeIfPresent(String.self, forKey: .key)
        file = try c.decodeIfPresent(String.self, forKey: .file)
    }
}

/// Domanda guidata con opzioni (pannello sopra il composer).
nonisolated struct AriaElicitation: Codable, Sendable, Identifiable, Hashable {
    nonisolated struct Assembly: Codable, Sendable, Hashable { let intro: String? }

    let id: String
    let question: String
    let mode: String
    let allowCustom: Bool
    let options: [AriaElicitationOption]
    let steps: [AriaElicitationStep]?
    let assembly: Assembly?
    let topic: String?
    let submit: String?

    enum CodingKeys: String, CodingKey {
        case id, question, mode, options, steps, assembly, topic, submit
        case allowCustom = "allow_custom"
    }

    init(id: String, question: String, mode: String = "single", allowCustom: Bool, options: [AriaElicitationOption],
         submit: String? = nil) {
        self.id = id
        self.question = question
        self.mode = mode
        self.allowCustom = allowCustom
        self.options = options
        self.submit = submit
        steps = nil
        assembly = nil
        topic = nil
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        question = try c.decodeIfPresent(String.self, forKey: .question) ?? ""
        mode = try c.decodeIfPresent(String.self, forKey: .mode) ?? "single"
        allowCustom = try c.decodeIfPresent(Bool.self, forKey: .allowCustom) ?? false
        options = try c.decodeIfPresent([AriaElicitationOption].self, forKey: .options) ?? []
        steps = try c.decodeIfPresent([AriaElicitationStep].self, forKey: .steps)
        assembly = try c.decodeIfPresent(Assembly.self, forKey: .assembly)
        topic = try c.decodeIfPresent(String.self, forKey: .topic)
        submit = try c.decodeIfPresent(String.self, forKey: .submit)
    }

    /// Una domanda singola è una catena di un solo passo (elicitationSteps della web).
    var allSteps: [AriaElicitationStep] {
        if let steps, !steps.isEmpty { return steps }
        return [AriaElicitationStep(id: id, question: question, mode: mode, allowCustom: allowCustom,
                                    options: options, topic: topic)]
    }

    /// La web mostra il pannello solo con almeno 2 opzioni.
    var isUsable: Bool { allSteps.contains { $0.options.count >= 2 } }
}

/// Checklist di uno step di procedura (`aria.task_list`).
nonisolated struct AriaTaskList: Codable, Sendable, Hashable {
    nonisolated struct Task: Codable, Sendable, Hashable, Identifiable {
        let id: String
        let index: Int
        let text: String
    }

    let agent: String?
    let stepNumber: Int
    let stepTitle: String
    let stepLabel: String?
    let revision: Int?
    let tasks: [Task]

    enum CodingKeys: String, CodingKey {
        case agent, revision, tasks
        case stepNumber = "step_number"
        case stepTitle = "step_title"
        case stepLabel = "step_label"
    }

    var isSafety: Bool { agent == "safety" }

    /// "Step 2" / "Safety 1", o l'etichetta data dal backend (stepLabel della web).
    var label: String {
        if let stepLabel, !stepLabel.isEmpty { return stepLabel }
        return isSafety ? "Safety \(stepNumber)" : "Step \(stepNumber)"
    }
}

nonisolated struct AriaMemoryProposal: Codable, Sendable, Hashable, Identifiable {
    let factId: String
    let content: String
    let reason: String?
    let kind: String?

    var id: String { factId }

    enum CodingKeys: String, CodingKey {
        case content, reason, kind
        case factId = "fact_id"
    }
}

nonisolated struct AriaMemoryLearned: Codable, Sendable, Hashable {
    let content: String
    let action: String?
}

// MARK: - Real-time Learning

/// La domanda del "Real-time Learning" (ValidationRequestPayload della web): il gate di confidenza
/// non è sicuro della risposta e chiede all'operatore di confermarla o correggerla.
nonisolated struct AriaValidationRequest: Codable, Sendable, Hashable {
    let question: String
    let options: [AriaElicitationOption]
    let targeted: Bool?
    let reason: String?
    /// La frase "perché Aria non è sicura" di val-dev-2; dev la mette in `reason`.
    let explanation: String?

    /// Almeno la domanda e due opzioni (isUsableValidationRequest della web).
    var isUsable: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && options.count >= 2
    }

    /// validationReasonText della web: `low_confidence` è un'etichetta, non una frase.
    var reasonText: String? {
        if let explanation, !explanation.trimmingCharacters(in: .whitespaces).isEmpty { return explanation }
        guard let reason, !reason.isEmpty, reason != "low_confidence" else { return nil }
        return reason
    }

    /// Il pannello di domande che la pone (toValidationElicitation della web): l'id viene dal messaggio,
    /// e la risposta scritta è sempre ammessa — è la cosa più preziosa che il gate raccoglie.
    func elicitation(messageId: String) -> AriaElicitation {
        AriaElicitation(id: "validation-\(messageId)", question: question, allowCustom: true, options: options,
                        submit: "learning")
    }
}

/// Verdetto del gate di confidenza su una risposta finita (`aria.answer_confidence`).
nonisolated struct AriaAnswerConfidence: Codable, Sendable, Hashable {
    let score: Double?
    let threshold: Double?
    let needsValidation: Bool
    var validationRequest: AriaValidationRequest?

    enum CodingKeys: String, CodingKey {
        case score, threshold
        case needsValidation = "needs_validation"
        case validationRequest = "validation_request"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        score = try? c.decodeIfPresent(Double.self, forKey: .score)
        threshold = try? c.decodeIfPresent(Double.self, forKey: .threshold)
        needsValidation = try c.decode(Bool.self, forKey: .needsValidation)
        // Una domanda annidata inutilizzabile si scarta, come quella arrivata da sola.
        validationRequest = (try? c.decodeIfPresent(AriaValidationRequest.self, forKey: .validationRequest))
            .flatMap { $0.isUsable ? $0 : nil }
    }
}

/// Esito di POST memory-facts/validation (camelCase lato API).
nonisolated struct AriaMemoryValidationResponse: Decodable, Sendable, Hashable {
    nonisolated struct Item: Decodable, Sendable, Hashable {
        let factId: String?
        let content: String
        let action: String

        /// "added" / "updated" se imparato subito, "proposed" se va approvato.
        var isProposed: Bool { action == "proposed" }
    }

    let learned: Int?
    let proposals: Int?
    let items: [Item]?
    /// Quando/dove vale ciò che Aria ha imparato, scritto da Aria.
    let context: String?
}

nonisolated struct AriaSourceRef: Codable, Sendable, Hashable {
    let title: String
    let url: String?
}

nonisolated struct AriaUsage: Codable, Sendable, Hashable {
    let inputTokens: Int?
    let outputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

nonisolated enum AriaStreamEvent: Sendable {
    case created(responseId: String)
    case textDelta(String)
    case textDone(String)
    case reasoningDelta(String)
    case completed(status: String, usage: AriaUsage?)
    case failed(String)
    case toolCall(AriaToolCall)
    case artifact(AriaArtifact)
    case uiAction(AriaUIAction)
    case imageReference(AriaImageReference)
    case elicitation(AriaElicitation)
    case sources([AriaSourceRef])
    case memoryContext(facts: [String], raw: AriaJSON)
    case memoryLearned([AriaMemoryLearned])
    case memoryProposal(AriaMemoryProposal)
    case answerConfidence(AriaAnswerConfidence)
    case validationRequest(AriaValidationRequest)
    case diagnosticState(episode: Int?)
    case interrupt(AriaInterrupt)
    case taskList(AriaTaskList)
    /// Eventi di pipeline della web (PIPELINE_EVENTS): passo di intent, retrieval, CMMS, azioni esterne.
    case pipeline(name: String, data: AriaJSON)
    case ignored

    static let pipelineEvents: Set<String> = [
        "aria.intent_detected", "aria.retrieval_complete", "aria.query_rewritten", "aria.task_list",
        "aria.cmms_context_loaded", "aria.cmms_work_order_created", "aria.cmms_procedure_step",
        "aria.cmms_entity_referenced", "aria.memory_context_loaded", "aria.external_action",
    ]

    private nonisolated struct Created: Decodable { let id: String }
    private nonisolated struct Delta: Decodable { let delta: String }
    private nonisolated struct Done: Decodable { let text: String? }
    private nonisolated struct Completed: Decodable { let status: String?; let usage: AriaUsage? }
    private nonisolated struct Failure: Decodable { let message: String? }
    private nonisolated struct RawSource: Decodable { let filename: String?; let title: String?; let url: String? }
    private nonisolated struct Sources: Decodable { let sources: [RawSource] }
    private nonisolated struct MemoryContext: Decodable { let facts: [String] }
    private nonisolated struct Learned: Decodable { let items: [AriaMemoryLearned] }
    private nonisolated struct Diagnostic: Decodable { let episodeNumber: Int?
        enum CodingKeys: String, CodingKey { case episodeNumber = "episode_number" } }

    init(_ sse: AriaSSEEvent) {
        let raw = Data(sse.data.utf8)
        func decode<T: Decodable>(_ type: T.Type) -> T? { try? JSONDecoder().decode(type, from: raw) }
        func pipelineOrIgnored() -> AriaStreamEvent {
            guard Self.pipelineEvents.contains(sse.event), let json = decode(AriaJSON.self) else { return .ignored }
            return .pipeline(name: sse.event, data: json)
        }

        self = switch sse.event {
        case "response.created": .created(responseId: decode(Created.self)?.id ?? "")
        case "response.output_text.delta": decode(Delta.self).map { .textDelta($0.delta) } ?? .ignored
        case "response.output_text.done": .textDone(decode(Done.self)?.text ?? "")
        case "response.reasoning_summary_text.delta": decode(Delta.self).map { .reasoningDelta($0.delta) } ?? .ignored
        case "response.completed":
            decode(Completed.self).map { .completed(status: $0.status ?? "completed", usage: $0.usage) }
                ?? .completed(status: "completed", usage: nil)
        case "error": .failed(decode(Failure.self)?.message ?? String(localized: "Stream error"))
        case "aria.tool_call": decode(AriaToolCall.self).map { .toolCall($0) } ?? .ignored
        case "aria.ui_artifact": decode(AriaArtifact.self).map { .artifact($0) } ?? .ignored
        case "aria.ui_action": decode(AriaUIAction.self).map { .uiAction($0) } ?? .ignored
        case "aria.image_reference": decode(AriaImageReference.self).map { .imageReference($0) } ?? .ignored
        case "aria.elicitation": decode(AriaElicitation.self).map { .elicitation($0) } ?? .ignored
        case "aria.sources":
            .sources((decode(Sources.self)?.sources ?? []).map {
                AriaSourceRef(title: $0.title ?? $0.filename ?? "source", url: $0.url)
            })
        case "aria.memory_context_loaded":
            .memoryContext(facts: decode(MemoryContext.self)?.facts ?? [], raw: decode(AriaJSON.self) ?? .null)
        case "aria.memory_learned": .memoryLearned(decode(Learned.self)?.items ?? [])
        case "aria.memory_proposal": decode(AriaMemoryProposal.self).map { .memoryProposal($0) } ?? .ignored
        case "aria.answer_confidence": decode(AriaAnswerConfidence.self).map { .answerConfidence($0) } ?? .ignored
        case "aria.validation_request":
            decode(AriaValidationRequest.self).flatMap { $0.isUsable ? AriaStreamEvent.validationRequest($0) : nil } ?? .ignored
        case "aria.diagnostic_state": .diagnosticState(episode: decode(Diagnostic.self)?.episodeNumber)
        case "aria.interrupt": decode(AriaInterrupt.self).map { .interrupt($0) } ?? .ignored
        case "aria.task_list": decode(AriaTaskList.self).map { .taskList($0) } ?? pipelineOrIgnored()
        default: pipelineOrIgnored()
        }
    }
}

// MARK: - Storico sessioni

nonisolated struct AriaSessionSummary: Decodable, Sendable, Identifiable, Hashable {
    let sessionId: String
    let title: String?
    let status: String?
    let createdAt: String?
    let lastActivityAt: String?

    var id: String { sessionId }

    enum CodingKeys: String, CodingKey {
        case title, status
        case sessionId = "session_id"
        case createdAt = "created_at"
        case lastActivityAt = "last_activity_at"
    }

    var lastActivity: Date? { AriaDate.parse(lastActivityAt ?? createdAt) }
}

/// Riga di GET v1/agent/sessions/{id}/messages (snake_case, tranne `responseId`).
nonisolated struct AriaPersistedMessage: Decodable, Sendable {
    let id: AriaFlexibleID?
    let role: String
    let text: String?
    let reasoning: String?
    let sources: [AriaSourceRef]?
    let toolCalls: AriaLossyArray<AriaToolCall>?
    let artifacts: AriaLossyArray<AriaArtifact>?
    let uiActions: AriaLossyArray<AriaUIAction>?
    let imageReferences: AriaLossyArray<AriaImageReference>?
    let pipeline: [AriaJSON]?
    let usage: AriaUsage?
    let responseId: String?
    let episode: Int?

    enum CodingKeys: String, CodingKey {
        case id, role, text, reasoning, sources, artifacts, pipeline, usage, responseId, episode
        case toolCalls = "tool_calls"
        case uiActions = "ui_actions"
        case imageReferences = "image_references"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try? c.decodeIfPresent(AriaFlexibleID.self, forKey: .id)
        role = try c.decode(String.self, forKey: .role)
        text = try? c.decodeIfPresent(String.self, forKey: .text)
        reasoning = try? c.decodeIfPresent(String.self, forKey: .reasoning)
        sources = try? c.decodeIfPresent([AriaSourceRef].self, forKey: .sources)
        toolCalls = try? c.decodeIfPresent(AriaLossyArray<AriaToolCall>.self, forKey: .toolCalls)
        artifacts = try? c.decodeIfPresent(AriaLossyArray<AriaArtifact>.self, forKey: .artifacts)
        uiActions = try? c.decodeIfPresent(AriaLossyArray<AriaUIAction>.self, forKey: .uiActions)
        imageReferences = try? c.decodeIfPresent(AriaLossyArray<AriaImageReference>.self, forKey: .imageReferences)
        pipeline = try? c.decodeIfPresent([AriaJSON].self, forKey: .pipeline)
        usage = try? c.decodeIfPresent(AriaUsage.self, forKey: .usage)
        responseId = try? c.decodeIfPresent(String.self, forKey: .responseId)
        episode = try? c.decodeIfPresent(Int.self, forKey: .episode)
    }
}

nonisolated struct AriaPendingInterruptResponse: Decodable, Sendable {
    let interrupt: AriaInterrupt?
}

nonisolated struct AriaAnswerFeedbackResponse: Decodable, Sendable {
    let recorded: Bool?
    let learned: Bool?
    let vote: String?
}

// MARK: - Azienda / stabilimento

nonisolated struct AriaCompany: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let myRole: String?
}

nonisolated struct AriaPlant: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let code: String?
}

nonisolated struct AriaSuggestionsResponse: Decodable, Sendable {
    let suggestions: [String]
}

// MARK: - Closeout (camelCase lato API)

nonisolated struct AriaCloseoutRequest: Encodable, Sendable {
    var workOrder = true
    var report = false
    var confirm: Bool? = nil
    var title: String? = nil
    var assigneeId: String? = nil
    var priority: String? = nil
    var dueDate: String? = nil
    var category: String? = nil
    var location: String? = nil
    var notes: String? = nil
    var startDate: String? = nil
    var recurrenceType: String? = nil
    var recurrenceInterval: Int? = nil
    /// "file" = lascia i lavori già previsti quel giorno; "shift" = spostali.
    var conflictChoice: String? = nil
}

nonisolated struct AriaCloseoutProposal: Decodable, Sendable {
    nonisolated struct Candidate: Decodable, Sendable, Identifiable, Hashable { let id: String; let name: String; let reason: String? }
    nonisolated struct Assignee: Decodable, Sendable { let selected: String?; let candidates: [Candidate]? }
    nonisolated struct Location: Decodable, Sendable, Identifiable, Hashable { let id: Int; let name: String }
    nonisolated struct Unresolved: Decodable, Sendable { let value: String?; let valid: [String]? }
    nonisolated struct Conflict: Decodable, Sendable, Identifiable {
        let system: String?
        let id: AriaFlexibleID
        let title: String
        let dueDate: String?
    }

    let title: String
    let description: String?
    let priority: String?
    let category: String?
    let assetTag: String?
    let dueDate: String?
    let targets: [String]?
    let assignee: Assignee?
    let categoryOptions: [String]?
    let locationOptions: [Location]?
    let startDate: String?
    let recurrenceType: String?
    let recurrenceInterval: Int?
    let unresolved: [String: Unresolved]?
    let conflicts: [Conflict]?
}

nonisolated struct AriaExternalWriteOutcome: Decodable, Sendable {
    let status: String
    let id: AriaFlexibleID?
    let title: String?
    let url: String?
    let error: String?
}

nonisolated struct AriaCloseoutResult: Decodable, Sendable {
    let confirmed: Bool
    let workOrderId: String?
    let workOrderTitle: String?
    let workOrderStatus: String?
    let aria: AriaExternalWriteOutcome?
    let maintainx: AriaExternalWriteOutcome?
    let proposal: AriaCloseoutProposal?
}

// MARK: - Utilità

/// Array che scarta gli elementi che non si decodificano invece di far fallire tutto.
nonisolated struct AriaLossyArray<Element: Decodable & Sendable>: Decodable, Sendable {
    var items: [Element]

    init(from decoder: any Decoder) throws {
        var c = try decoder.unkeyedContainer()
        var out: [Element] = []
        while !c.isAtEnd {
            if let v = try? c.decode(Element.self) {
                out.append(v)
            } else if (try? c.decode(AriaJSON.self)) == nil {
                break
            }
        }
        items = out
    }
}

/// Date del backend: ISO 8601 con o senza frazioni e fuso (Python spesso li omette).
nonisolated enum AriaDate {
    static func parse(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let withZone = raw.hasSuffix("Z") || raw.range(of: #"[+-]\d\d:?\d\d$"#, options: .regularExpression) != nil
            ? raw : raw + "Z"
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: withZone) { return date }
        return ISO8601DateFormatter().date(from: withZone)
    }
}

/// Id di sessione come la web (nanoid: 21 caratteri URL-safe).
nonisolated enum AriaNanoID {
    private static let alphabet = Array("useandom-26T198340PX75pxJACKVERYMINDBUSHWOLF_GQZbfghjklqvwyzrict")

    static func make(size: Int = 21) -> String {
        var generator = SystemRandomNumberGenerator()
        return String((0..<size).map { _ in alphabet[Int(generator.next() % UInt64(alphabet.count))] })
    }
}
