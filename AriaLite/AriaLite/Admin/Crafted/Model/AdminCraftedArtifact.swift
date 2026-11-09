//
//  AdminCraftedArtifact.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Una cosa che Aria ha fatto su richiesta dalla pagina Crafted (CraftedArtifact della web): cosa è stato
//  chiesto, la conversazione in cui è nata, lo stato e le card prodotte. Si tiene sul dispositivo
//  (AdminCraftedArtifactStore) con le stesse chiavi JSON della web; le modifiche stanno in `versions`.
//

import Foundation

nonisolated enum AdminCraftedArtifactStatus: String, Codable, Sendable {
    /// Aria ci sta lavorando.
    case generating
    /// La card è arrivata e si tiene qui.
    case ready
    /// Aria ha risposto a parole: una domanda, o una pausa per l'approvazione.
    case needsChat = "needs-chat"
    /// Il turno è fallito o si è interrotto prima della fine.
    case failed
}

nonisolated struct AdminCraftedArtifact: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    /// Quello che si è chiesto, con le parole dell'operatore.
    var request: String
    /// La conversazione in cui Aria l'ha fatto.
    var sessionId: String
    var status: AdminCraftedArtifactStatus
    /// Solo i deliverable che il turno ha prodotto.
    var artifacts: [AriaArtifact]
    /// Le parole di Aria quando serve la chat, o l'errore quando è fallito; il testo stesso se ha scritto il risultato.
    var note: String?
    /// Le modifiche salvate sopra la risposta di Aria, dalla più vecchia; `nil` finché non ce n'è una.
    var versions: [AdminCraftedArtifactVersion]?
    var createdAt: Date
    var updatedAt: Date

    /// Il numero della versione attuale (1 = l'originale di Aria).
    var currentVersion: Int { AdminCraftedEditing.currentNumber(versions?.map(\.number)) }

    /// Ha almeno una modifica salvata (il segno "modificato" della lista).
    var isEdited: Bool { !(versions ?? []).isEmpty }
}

/// Un cambiamento fatto da Aria su richiesta (AriaRequest della web): cosa si è chiesto, chi, e in quale conversazione.
nonisolated struct AdminCraftedAriaRequest: Codable, Hashable, Sendable {
    var instruction: String
    var requestedBy: String?
    var sessionId: String
}
