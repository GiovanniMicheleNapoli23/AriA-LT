//
//  AdminAgentStudioRunViewModel+Display.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Valori già pronti per la schermata del run: pre-flight, rifiuto, approvazioni, riassunto, tempo trascorso.
//  Solo proprietà calcolate; lo stato resta nel view model.
//

import Foundation

extension AdminAgentStudioRunViewModel {
    // MARK: Intestazione

    /// "Check", "Simulation" o "Real".
    var modeChipText: String? {
        switch mode {
        case .check?: String(localized: "Check")
        case .simulate?: String(localized: "Simulation")
        case .run?: String(localized: "Real")
        case nil: nil
        }
    }

    var isRealMode: Bool { mode == .run }

    /// Costo e token su una riga, se ci sono.
    var usageText: String? {
        let parts = [costText, tokensText].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Il tempo di un run finito (a run vivo lo calcola la vista con il suo orologio).
    var finishedElapsedText: String? {
        guard !isActive else { return nil }
        let seconds: TimeInterval?
        if let ms = run?.durationMs ?? live.summary?.durationMs {
            seconds = Double(ms) / 1000
        } else if let start = startedAt, let end = run?.finishedAt {
            seconds = end.timeIntervalSince(start)
        } else if live.elapsedMs > 0 {
            seconds = Double(live.elapsedMs) / 1000
        } else {
            seconds = nil
        }
        return seconds.map { Self.elapsedText($0) }
    }

    /// "1m 5s".
    static func elapsedText(_ seconds: TimeInterval) -> String {
        let style: Duration.UnitsFormatStyle = .units(allowed: [.hours, .minutes, .seconds], width: .narrow)
        let text = Duration.seconds(max(0, seconds.rounded(.down))).formatted(style)
        return text.isEmpty ? "0s" : text
    }

    // MARK: Avvisi

    /// L'errore dello stream, se non ripete quello del record.
    var liveErrorMessage: String? {
        guard let message = live.errorMessage, message != runError else { return nil }
        return message
    }

    // MARK: Pre-flight

    var preflightChecks: [AdminAgentStudioLiveRun.Check] { live.connectorChecks + live.policyChecks }

    var hasPreflight: Bool { !preflightChecks.isEmpty }

    /// Almeno un controllo non è passato (fallito o con avviso): il blocco si apre da solo.
    var preflightFailed: Bool { preflightChecks.contains { $0.verdict != .passed } }

    // MARK: Rifiuto e approvazioni

    var isRefused: Bool { live.phase == .refused || run?.refused == true }

    /// I motivi del rifiuto, uno per riga (dallo stream, o dal record per un run già chiuso).
    var refusalReasons: [String] {
        guard isRefused else { return [] }
        if let refusal = live.refusal {
            return refusal.blockers.isEmpty ? [refusal.reason] : refusal.blockers
        }
        return run?.blockers ?? []
    }

    /// Le approvazioni su cui il run è fermo.
    var pendingApprovals: [AdminAgentStudioLiveRun.PendingApproval] {
        isActive ? live.pendingApprovals : []
    }

    // MARK: Cronologia

    /// Una cronologia ha senso quando i passi sono partiti: non per un check, né per un run rifiutato.
    var showsTimeline: Bool {
        guard !isRefused, !rows.isEmpty else { return false }
        return !(mode == .check && live.nodes.isEmpty)
    }

    /// Nessuna riga e nessuna fase ancora: si sta aprendo il collegamento.
    var isConnecting: Bool { live.phase == .connecting && rows.isEmpty && !isRefused }

    /// La riga da portare in vista: quella in corso, o quella ferma su un'approvazione.
    var focusRowId: String? {
        guard isActive else { return nil }
        let rows = rows
        return (rows.first { $0.state == .running } ?? rows.first { $0.state == .needsApproval })?.id
    }

    // MARK: Riassunto e file

    /// Il riassunto che arriva dallo stream, o quello del record.
    var narrativeText: String? {
        if !live.narrative.isEmpty { return live.narrative }
        guard let saved = run?.narrative, !saved.isEmpty else { return nil }
        return saved
    }

    var artifacts: [AdminAgentStudioLiveRun.Artifact] { live.artifacts }

    // MARK: Registro tecnico

    var logEvents: [AdminAgentStudioRunEvent] { live.events }
}
