//
//  AdminScenarioBackfillViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il backfill degli scenari: rilegge le sessioni concluse a lotti di 50 finché il server dice `hasMore`.
//  È lungo: gira in un Task del view model (sopravvive al cambio di scheda), mostra i totali e si può fermare.
//  Ripeterlo è sicuro: ogni sessione si conta una volta sola.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminScenarioBackfillViewModel {
    enum Phase: Equatable {
        case idle
        case running
        case finished
        case stopped
        case failed(String)
    }

    let backend: AriaBackend

    private(set) var phase: Phase = .idle
    private(set) var processed = 0
    private(set) var recorded = 0
    private(set) var skipped = 0
    private(set) var optedOut = 0
    /// L'ultimo giro rigiudicava anche le sessioni già valutate.
    private(set) var isForced = false
    var showsConfirmation = false

    /// Chiamato a fine giro (anche fermato) per ricaricare scenari e revisioni.
    @ObservationIgnored var onFinished: (@MainActor () async -> Void)?
    @ObservationIgnored private var task: Task<Void, Never>?
    /// Cambia a ogni giro e a ogni `reset()`: un giro vecchio che finisce dopo non tocca più niente.
    @ObservationIgnored private var generation = 0

    static let batchSize = 50
    /// Un tetto ai lotti: un server che dice sempre `hasMore` non tiene l'app in giro per sempre.
    static let maxBatches = 200

    init(backend: AriaBackend) {
        self.backend = backend
    }

    var isRunning: Bool { phase == .running }

    /// La riga di stato sotto il titolo del riquadro.
    var progressText: String {
        String(localized: "\(processed) sessions read · \(recorded) recorded · \(skipped) skipped")
    }

    var optedOutText: String? {
        optedOut > 0 ? String(localized: "\(optedOut) sessions excluded by their owners") : nil
    }

    var title: String {
        switch phase {
        case .idle: ""
        case .running: isForced ? String(localized: "Re-judging every session…") : String(localized: "Assessing new sessions…")
        case .finished: String(localized: "Backfill complete")
        case .stopped: String(localized: "Backfill stopped")
        case .failed: String(localized: "Backfill interrupted")
        }
    }

    var errorMessage: String? {
        if case .failed(let message) = phase { return message }
        return nil
    }

    /// Icona e tono del riquadro a giro finito.
    var resultSystemImage: String {
        switch phase {
        case .finished: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        default: "pause.circle.fill"
        }
    }

    var resultTone: AdminScenarioTone {
        switch phase {
        case .finished: .positive
        case .failed: .warning
        default: .neutral
        }
    }

    // MARK: Azioni

    func start(force: Bool) {
        guard !isRunning else { return }
        processed = 0
        recorded = 0
        skipped = 0
        optedOut = 0
        isForced = force
        phase = .running
        generation += 1
        let current = generation
        task = Task { await run(force: force, generation: current) }
    }

    func stop() {
        task?.cancel()
    }

    func dismiss() {
        guard !isRunning else { return }
        phase = .idle
    }

    private func run(force: Bool, generation current: Int) async {
        guard let companyId = backend.activeCompanyId else {
            phase = .failed(AriaError.missingCompany.localizedDescription)
            return
        }
        var batches = 0
        do {
            while batches < Self.maxBatches {
                try Task.checkCancellation()
                let result = try await backend.api.call(AdminScenarioAnalysisAPI.backfill(
                    companyId: companyId, limit: Self.batchSize, force: force))
                guard current == generation else { return }
                batches += 1
                processed += result.processed ?? 0
                recorded += result.recorded ?? 0
                skipped += result.skipped ?? 0
                optedOut += result.optedOut ?? 0
                // Finito, o un lotto vuoto che direbbe di continuare all'infinito.
                guard result.hasMore == true, (result.processed ?? 0) > 0 else { break }
            }
            guard current == generation else { return }
            phase = Task.isCancelled ? .stopped : .finished
        } catch {
            guard current == generation else { return }
            if let message = AdminScenarioFailure.message(for: error, backend: backend) {
                phase = .failed(message)
            } else {
                phase = .stopped
            }
        }
        task = nil
        await onFinished?()
    }

    func reset() {
        task?.cancel()
        task = nil
        generation += 1
        phase = .idle
        processed = 0
        recorded = 0
        skipped = 0
        optedOut = 0
        isForced = false
        showsConfirmation = false
    }
}
