//
//  AdminAgentStudioRunViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un run visto dal vivo: o lo avvia (POST workflow-runs) o si aggancia a uno già in corso (GET …/events).
//  Le righe NDJSON si sommano in AdminAgentStudioLiveRun man mano che arrivano; la vista legge `rows`,
//  l'avanzamento e il resto già pronti. Se lo stream cade il run non si perde: si prosegue con gli eventi
//  da dove si era arrivati, poi con il record. A run finito si legge anche il record salvato.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminAgentStudioRunViewModel {
    enum Source: Sendable {
        /// Avvia il run (POST) e lo segue.
        case start(AdminAgentStudioRunBody, mode: AdminAgentStudioRunMode)
        /// Si aggancia a un run già partito: rilegge gli eventi dall'inizio e poi li segue.
        case attach(runId: String)
    }

    let backend: AriaBackend
    let source: Source
    let workflowId: String?

    /// Lo stato in streaming, pubblicato al massimo ogni ~100 ms e solo se è cambiato qualcosa che la vista mostra.
    /// È una copia leggera: testo del riassunto e registro non ci sono (si leggono da `narrativeText` e `logEvents`).
    private(set) var live: AdminAgentStudioLiveRun
    /// Versioni pubblicate di testo e registro: chi li legge si aggiorna solo quando cambiano, senza copiarli.
    private(set) var narrativeVersion = 0
    /// Il riassunto dallo stream ha del testo: cambia una volta sola, così la scheda compare senza seguire ogni delta.
    private(set) var hasStreamedNarrative = false
    private(set) var logVersion = 0
    /// Il record salvato del run (si legge a fine stream e mentre si fa polling).
    private(set) var run: AdminAgentStudioRun?
    private(set) var runError: String?
    private(set) var workflowName: String?
    /// I passi del workflow in ordine di grafo: danno i titoli e le righe ancora in attesa.
    private(set) var workflowSteps: [AdminAgentStudioWorkflowStep]
    /// Un avviso non bloccante (il run continua sul server).
    private(set) var notice: String?

    private(set) var isCancelling = false
    private(set) var wasCancelled = false
    var showsCancelConfirmation = false
    var actionError: String?

    var showsActionError: Bool {
        get { actionError != nil }
        set { if !newValue { actionError = nil } }
    }

    /// Lo stato su cui si somma subito; `live` ne è la copia pubblicata.
    @ObservationIgnored private var pending: AdminAgentStudioLiveRun
    @ObservationIgnored private var lastPublish = ContinuousClock.now.advanced(by: .seconds(-1))
    @ObservationIgnored private var flushTask: Task<Void, Never>?
    @ObservationIgnored private var isStreaming = false
    @ObservationIgnored private var hasStarted = false
    @ObservationIgnored private var hasNotifiedEnd = false
    /// Questo VM ha visto il run vivo: solo allora la sua fine va notificata (non se si apre un run già concluso).
    @ObservationIgnored private var observedActive = false
    @ObservationIgnored private var hasCheckedAttach = false
    @ObservationIgnored private let network: AriaNetworkMonitor
    /// L'app è in primo piano (lo dice la schermata): in background il record non si rilegge.
    @ObservationIgnored var isInForeground = true
    @ObservationIgnored private let onActivityChanged: () async -> Void

    /// Ogni quanto si rilegge il record se gli eventi non arrivano più: si rallenta se non cambia niente.
    private static let pollIntervals: [Duration] = [.seconds(4), .seconds(8), .seconds(15)]
    /// Attese tra un tentativo di riconnessione e l'altro (al massimo tre).
    private static let backoff: [Duration] = [.seconds(1), .seconds(2), .seconds(4)]
    private static let publishInterval: Duration = .milliseconds(100)

    init(backend: AriaBackend, source: Source, workflowId: String? = nil, workflowName: String? = nil,
         workflowSteps: [AdminAgentStudioWorkflowStep] = [],
         network: AriaNetworkMonitor? = nil,
         onActivityChanged: @escaping () async -> Void) {
        self.backend = backend
        // `nil` = la rete del telefono: un valore di default si valuta fuori dal MainActor, dove `.shared` non si legge.
        self.network = network ?? .shared
        self.source = source
        self.onActivityChanged = onActivityChanged
        self.workflowSteps = workflowSteps
        let initial: AdminAgentStudioLiveRun
        switch source {
        case .start(let body, let mode):
            self.workflowId = workflowId ?? body.workflowId
            self.workflowName = workflowName ?? body.workflowName
            initial = AdminAgentStudioLiveRun(mode: mode)
        case .attach(let runId):
            self.workflowId = workflowId
            self.workflowName = workflowName
            initial = AdminAgentStudioLiveRun(runId: runId)
        }
        live = initial.displaySnapshot()
        pending = initial
    }

    // MARK: Esecuzione

    /// La vista lo lega al suo `.task`: torna quando lo stream finisce o il task è cancellato.
    /// Richiamato dopo una cancellazione non rilancia il run: si riaggancia dagli eventi.
    func run() async {
        guard !isStreaming else { return }
        isStreaming = true
        defer { isStreaming = false }
        async let steps: Void = loadWorkflowSteps()

        switch source {
        case .start(let body, _):
            observedActive = true
            if hasStarted { await resume() } else { hasStarted = true; await start(body) }
        case .attach(let runId):
            // Senza sapere che il run era vivo all'aggancio, la sua fine non si notifica.
            if !hasCheckedAttach {
                hasCheckedAttach = true
                if workflowId != nil {
                    await loadRecord()
                    observedActive = run?.isActive ?? false
                }
            }
            await follow(runId)
        }
        publish()
        await steps

        guard !Task.isCancelled else { return }
        await loadRecord()
        _ = endIfRecordInactive()
        if observedActive, !pending.isActive { await notifyEnded() }
    }

    private func start(_ body: AdminAgentStudioRunBody) async {
        var failure: (any Error)?
        do {
            for try await line in AdminAgentStudioAPI.runLines(body, api: backend.api) {
                try await checkAccess(line)
                ingest(line)
            }
        } catch {
            failure = error
        }
        guard !Task.isCancelled, pending.isActive else { return }
        // L'accesso è stato tolto: non si prosegue con gli eventi, che direbbero lo stesso 403.
        if let failure, AdminAgentStudioFailure.isAccessLoss(failure) {
            fail(failure)
            return
        }
        // Lo stream è caduto (o finito) senza che il run abbia detto di essere finito.
        guard let runId = pending.runId else {
            if let failure, !(failure is URLError) {
                fail(failure)
            } else {
                notice = String(localized: "This run keeps going on the server: you'll find it under Needs attention.")
            }
            return
        }
        // Stream chiuso senza errori: il run è finito (la web fa lo stesso, e un run v1 non manda una riga finale).
        // Solo una pausa, o un errore, lasciano il run vivo sul server.
        if failure == nil, pending.phase != .paused {
            pending.markFinished(status: "completed")
            publish()
            return
        }
        await follow(runId)
    }

    /// Il task della vista è stato cancellato e rilanciato: la POST non si ripete.
    private func resume() async {
        guard pending.isActive else { return }
        guard let runId = pending.runId else {
            notice = String(localized: "This run keeps going on the server: you'll find it under Needs attention.")
            return
        }
        await follow(runId)
    }

    /// Gli eventi del run, con riconnessione; se non bastano, il record ogni pochi secondi.
    private func follow(_ runId: String) async {
        while pending.isActive, !Task.isCancelled {
            guard await attach(runId) else { return }
            guard pending.isActive, !Task.isCancelled else { return }
            guard workflowId != nil else {
                notice = String(localized: "Lost the connection to this run. It keeps going on the server.")
                return
            }
            await pollRecord()
        }
    }

    /// GET …/events?after=ultimo `seq`: rilegge ciò che manca e segue. `false` se la sessione è scaduta.
    private func attach(_ runId: String) async -> Bool {
        var drops = 0
        while pending.isActive, !Task.isCancelled {
            // Righe senza `seq` (la POST): non si sa da dove ripartire, quindi si rilegge tutto da zero
            // sullo stato azzerato, e i delta di testo non si sommano due volte.
            if pending.lastSeq == 0, pending.lineCount > 0 {
                pending.resetForReplay()
            }
            let linesBefore = pending.lineCount
            var dropped = false
            do {
                for try await line in AdminAgentStudioAPI.eventLines(runId: runId, after: pending.lastSeq, api: backend.api) {
                    try await checkAccess(line)
                    ingest(line)
                }
            } catch {
                dropped = true
                if Task.isCancelled { return true }
                if case .signedOut? = error as? AriaError {
                    _ = AdminAgentStudioFailure.message(for: error, backend: backend)
                    return false
                }
                // Un ruolo che non può più: riconnettersi ripeterebbe lo stesso rifiuto.
                if AdminAgentStudioFailure.isAccessLoss(error) {
                    fail(error)
                    return false
                }
            }
            guard pending.isActive, !Task.isCancelled else { return true }
            // Chiusura pulita senza un record con cui confrontarsi: è la fine (a meno di una pausa).
            if !dropped, workflowId == nil, pending.phase != .paused {
                pending.markFinished(status: "completed")
                publish()
                return true
            }
            // Lo stream si è chiuso con il run ancora vivo: il record dice se è davvero finito.
            await loadRecord()
            if endIfRecordInactive() { return true }
            drops = pending.lineCount > linesBefore ? 1 : drops + 1
            guard drops <= Self.backoff.count else { return true }
            try? await Task.sleep(for: Self.backoff[drops - 1])
        }
        return true
    }

    /// Rilegge il record finché il run è vivo; finisce con il task (la schermata chiusa), con la fine del run o
    /// quando si torna agli eventi. Offline o in background non chiama; senza novità aspetta di più (4, 8, 15 s).
    private func pollRecord() async {
        var step = 0
        while pending.isActive, !Task.isCancelled {
            try? await Task.sleep(for: Self.pollIntervals[step])
            guard !Task.isCancelled else { return }
            guard network.isOnline, isInForeground else {
                step = min(step + 1, Self.pollIntervals.count - 1)
                continue
            }
            let before = RecordSignature(run)
            await loadRecord()
            if endIfRecordInactive() { return }
            // Fermo su un'approvazione e ripartito altrove: si riaggancia agli eventi.
            if pending.phase == .paused, run?.status?.lowercased() == "running" { return }
            step = RecordSignature(run) == before ? min(step + 1, Self.pollIntervals.count - 1) : 0
        }
    }

    /// Ciò che del record dice se è cambiato qualcosa tra due letture.
    private struct RecordSignature: Equatable {
        let status: String?
        let finishedAt: Date?
        let steps: [AdminAgentStudioRunStep]
        let tokens: Int?
        let costEur: Double?

        init(_ run: AdminAgentStudioRun?) {
            status = run?.status
            finishedAt = run?.finishedAt
            steps = run?.steps ?? []
            tokens = run.map { ($0.inputTokens ?? 0) + ($0.outputTokens ?? 0) }
            costEur = run?.costEur
        }
    }

    // MARK: Somma e pubblicazione

    private func ingest(_ line: AriaJSON) {
        let before = pending.phase
        let hadRunId = pending.runId != nil
        pending.apply(line)
        // Un run appena partito da qui: l'elenco dei run attivi lo deve sapere (senza aspettare nello stream).
        if !hadRunId, pending.runId != nil, case .start = source {
            Task { await onActivityChanged() }
        }
        // I passi si mostrano subito; i delta di testo e i progressi si raggruppano.
        let type = AdminAgentStudioFields(line).string("type")
        let isStep = type == "step-start" || type == "step-end"
        if isStep || pending.phase != before || ContinuousClock.now - lastPublish >= Self.publishInterval {
            publish()
        } else {
            scheduleFlush()
        }
    }

    /// Le righe ravvicinate (i delta di testo) si pubblicano insieme, in coda.
    private func scheduleFlush() {
        guard flushTask == nil else { return }
        flushTask = Task { [weak self] in
            try? await Task.sleep(for: Self.publishInterval)
            guard !Task.isCancelled else { return }
            self?.publish()
        }
    }

    private func publish() {
        flushTask?.cancel()
        flushTask = nil
        // Si pubblica solo ciò che è cambiato: nessuna copia di registro e testo, nessun rinnovo inutile della vista.
        if pending.displayRevision != live.displayRevision { live = pending.displaySnapshot() }
        if pending.narrativeRevision != narrativeVersion {
            narrativeVersion = pending.narrativeRevision
            let hasText = !pending.narrative.isEmpty
            if hasText != hasStreamedNarrative { hasStreamedNarrative = hasText }
        }
        if pending.eventsRevision != logVersion { logVersion = pending.eventsRevision }
        lastPublish = .now
    }

    /// Un'ultima riga `permission_denied` dello stream: l'accesso è stato tolto a run aperto. Si tratta come il
    /// 403 corrispondente: `permission_denied` e `operation_forbidden` fanno rileggere i diritti; `not_a_member`
    /// chiude la sessione di un operatore come fa il client (checkMembership). Poi l'errore segue il percorso solito.
    private func checkAccess(_ line: AriaJSON) async throws {
        guard let error = AdminAgentStudioAPI.accessError(in: line) else { return }
        switch error {
        case .permissionDenied, .notOnPhone:
            backend.accessMayHaveChanged()
        case .http(_, "not_a_member") where backend.api.auth.isMobileSession:
            await backend.api.auth.discardSession()
            throw AriaError.signedOut
        default:
            break
        }
        throw error
    }

    private func fail(_ error: any Error) {
        let message = AdminAgentStudioFailure.message(for: error, backend: backend)
        pending.fail(message: message ?? String(localized: "The run could not be started."))
        publish()
    }

    // MARK: Record e passi

    var canReadRecord: Bool { workflowId != nil }

    private func loadRecord() async {
        guard let workflowId, let runId = pending.runId else { return }
        do {
            run = try await backend.api.call(AdminAgentStudioAPI.run(workflowId: workflowId, runId: runId)).value
            runError = nil
        } catch {
            // Subito dopo l'avvio il record può non esserci ancora.
            guard pending.isActive == false,
                  let message = AdminAgentStudioFailure.message(for: error, backend: backend) else { return }
            runError = message
        }
    }

    /// Se il record dice che il run è finito (e lo stream non l'ha detto), si chiude anche qui.
    private func endIfRecordInactive() -> Bool {
        guard pending.isActive, let run, !run.isActive else { return false }
        pending.markFinished(status: run.status ?? "completed")
        publish()
        return true
    }

    private func loadWorkflowSteps() async {
        guard workflowSteps.isEmpty, let workflowId else { return }
        guard let workflow = try? await backend.api.call(AdminAgentStudioAPI.workflow(id: workflowId)).value else { return }
        workflowSteps = AdminAgentStudioWorkflowStep.ordered(in: workflow)
        if workflowName == nil { workflowName = workflow.name }
    }

    private func notifyEnded() async {
        guard !hasNotifiedEnd else { return }
        hasNotifiedEnd = true
        await onActivityChanged()
    }

    // MARK: Stato per la vista

    var runId: String? { live.runId }

    /// Il riassunto dallo stream. Legge la versione pubblicata (per essere osservato) e il testo da chi lo somma.
    var streamedNarrative: String {
        _ = narrativeVersion
        return pending.narrative
    }

    /// Il registro tecnico: stesso schema di `streamedNarrative`.
    var streamedEvents: [AdminAgentStudioRunEvent] {
        _ = logVersion
        return pending.events
    }

    var title: String {
        workflowName ?? run?.workflowName ?? String(localized: "Run")
    }

    var mode: AdminAgentStudioRunMode? {
        if let mode = live.mode { return mode }
        let recorded = run?.mode
        return recorded.flatMap(AdminAgentStudioRunMode.init(rawValue:))
    }

    var modeLabel: String? { mode?.label }

    var isActive: Bool { live.isActive && !wasCancelled }

    /// Lo stato per la pastiglia (AdminAgentStudioStatus ne dà etichetta e colore).
    var statusForBadge: String? {
        if wasCancelled { return "cancelled" }
        switch live.phase {
        case .connecting: return run?.status ?? "queued"
        case .checking, .running: return "running"
        case .paused: return "paused"
        case .finished(let status):
            // Lo stato del record, se c'è, vale più di quello dedotto dallo stream.
            return run.flatMap { $0.isActive ? nil : $0.status } ?? status
        case .refused: return "refused"
        case .failed: return "failed"
        }
    }

    /// La cronologia: passi del grafo nell'ordine, ognuno con il suo stato.
    var rows: [AdminAgentStudioLiveStepRow] {
        AdminAgentStudioLiveStepRow.rows(steps: workflowSteps, live: live, record: run?.steps ?? [])
    }

    /// Passi conclusi e totali: quelli dichiarati dal server, se no quelli contati dalle righe.
    private func progress(of rows: [AdminAgentStudioLiveStepRow]) -> (done: Int, total: Int)? {
        if live.total > 0 { return (min(live.done, live.total), live.total) }
        let countable = rows.filter { $0.kind != "trigger" }
        guard !countable.isEmpty else { return nil }
        return (countable.filter(\.isFinished).count, countable.count)
    }

    /// 0…1, o `nil` finché non si sa quanti passi ci sono (barra indeterminata).
    var progressFraction: Double? {
        guard let progress = progress(of: rows), progress.total > 0 else { return nil }
        return Double(progress.done) / Double(progress.total)
    }

    /// "3 of 7 steps".
    var progressText: String? {
        guard let progress = progress(of: rows) else { return nil }
        return String(localized: "\(progress.done) of \(progress.total) steps")
    }

    /// Il passo in corso, solo finché il run è vivo.
    var currentStepTitle: String? {
        guard live.isActive else { return nil }
        let rows = rows
        if let running = rows.first(where: { $0.state == .running }) { return running.title }
        return live.currentNodeId.flatMap { id in rows.first { $0.nodeId == id }?.title }
    }

    /// Da quando gira (per il cronometro della vista).
    var startedAt: Date? { run?.startedAt ?? live.startedAt }

    var costText: String? {
        (live.costEur ?? run?.costEur).map { $0.formatted(.currency(code: "EUR")) }
    }

    var tokensText: String? {
        if live.inputTokens > 0 || live.outputTokens > 0 {
            return String(localized: "\(live.inputTokens) in · \(live.outputTokens) out")
        }
        if let input = run?.inputTokens, let output = run?.outputTokens {
            return String(localized: "\(input) in · \(output) out")
        }
        return nil
    }

    var fields: [AdminAssetField] {
        var rows: [AdminAssetField] = []
        func add(_ title: String, _ value: String?) {
            if let value, !value.isEmpty { rows.append(AdminAssetField(title: title, value: value)) }
        }
        add(String(localized: "Mode"), modeLabel)
        add(String(localized: "Source"), run?.source)
        add(String(localized: "Started"), startedAt?.formatted(date: .abbreviated, time: .shortened))
        add(String(localized: "Finished"), run?.finishedAt?.formatted(date: .abbreviated, time: .shortened))
        add(String(localized: "Duration"), durationText)
        add(String(localized: "Started by"), run?.startedBy)
        add(String(localized: "Scenario"), run?.scenarioName ?? live.scenarioName)
        add(String(localized: "Agents"), run.map { $0.agents.joined(separator: ", ") })
        add(String(localized: "Tokens"), tokensText)
        add(String(localized: "Cost"), costText)
        add(String(localized: "Accuracy"), (run?.accuracy ?? live.summary?.accuracy).map { "\($0)%" })
        add(String(localized: "Policy version"), run?.policyVersion.map(String.init))
        add(String(localized: "Run ID"), live.runId)
        return rows
    }

    private static let abbreviatedDurationStyle: Duration.UnitsFormatStyle = .units(allowed: [.hours, .minutes, .seconds], width: .abbreviated)

    private var durationText: String? {
        let units = Self.abbreviatedDurationStyle
        if let ms = run?.durationMs ?? live.summary?.durationMs { return Duration.milliseconds(ms).formatted(units) }
        guard let start = run?.startedAt, let end = run?.finishedAt, end >= start else { return nil }
        return Duration.seconds(end.timeIntervalSince(start)).formatted(units)
    }

    /// I contatori del riassunto che hanno un valore (per le tessere).
    var counters: [(title: String, value: Int, status: String)] {
        let all: [(String, Int?, String)]
        if let run {
            all = [(String(localized: "Ran"), run.ran, "ran"),
                   (String(localized: "Needs approval"), run.needsApproval, "needs_approval"),
                   (String(localized: "Blocked"), run.blocked, "blocked"),
                   (String(localized: "Not configured"), run.unconfigured, "unconfigured"),
                   (String(localized: "Skipped"), run.skipped, "skipped")]
        } else if let summary = live.summary {
            all = [(String(localized: "Ran"), summary.ran, "ran"),
                   (String(localized: "Needs approval"), summary.needsApproval, "needs_approval"),
                   (String(localized: "Blocked"), summary.blocked, "blocked"),
                   (String(localized: "Not configured"), summary.unconfigured, "unconfigured"),
                   (String(localized: "Skipped"), summary.skipped, "skipped")]
        } else {
            return []
        }
        return all.compactMap { title, value, status in value.map { (title, $0, status) } }
    }

    // MARK: Annulla

    var canCancel: Bool { isActive && live.runId != nil && !isCancelling }

    func cancel() async {
        guard canCancel, let runId = live.runId else { return }
        isCancelling = true
        defer { isCancelling = false }
        do {
            _ = try await backend.api.call(AdminAgentStudioAPI.cancelRun(runId: runId))
            wasCancelled = true
            pending.markFinished(status: "cancelled")
            publish()
            await loadRecord()
            await notifyEnded()
        } catch {
            actionError = AdminAgentStudioFailure.message(for: error, backend: backend)
        }
    }
}
