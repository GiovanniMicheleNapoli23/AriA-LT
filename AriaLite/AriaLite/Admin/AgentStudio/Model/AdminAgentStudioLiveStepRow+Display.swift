//
//  AdminAgentStudioLiveStepRow+Display.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Come si legge una riga della cronologia: etichetta dello stato, se si può aprire, uscita da mostrare.
//

import Foundation

extension AdminAgentStudioLiveStepRow {
    /// Il valore grezzo che AdminAgentStudioStatus sa tradurre in etichetta e tono.
    var statusKey: String {
        switch state {
        case .waiting: "waiting"
        case .running: "running"
        case .ran: "ran"
        case .simulated: "simulated"
        case .needsApproval: "needs_approval"
        case .blocked: "blocked"
        case .unconfigured: "unconfigured"
        case .skipped: "skipped"
        case .failed: "failed"
        }
    }

    var stateLabel: String { AdminAgentStudioStatus.label(for: statusKey) }

    /// La pastiglia accanto al titolo: serve solo per gli esiti che non sono "tutto bene".
    var showsStateTag: Bool {
        switch state {
        case .waiting, .running, .ran: false
        default: true
        }
    }

    /// "Step 2, Send email, Ran".
    var accessibilityTitle: String {
        String(localized: "Step \(index), \(title), \(stateLabel)")
    }

    /// Un passo concluso con qualcosa da leggere si apre al tocco.
    var isExpandable: Bool { isFinished && (reason != nil || displayOutput != nil) }

    /// L'uscita senza spazi in testa e in coda, e non oltre un limite ragionevole per il testo a schermo.
    var displayOutput: String? {
        guard let output else { return nil }
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.count > 20_000 ? String(trimmed.prefix(20_000)) + "…" : trimmed
    }

    /// Più righe di quelle mostrate di default: serve "Show more".
    var outputIsLong: Bool {
        guard let text = displayOutput else { return false }
        return text.count > 600 || text.split(separator: "\n", omittingEmptySubsequences: false).count > 12
    }
}
