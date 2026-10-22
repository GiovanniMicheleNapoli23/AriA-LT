//
//  AdminWorkflowRequests.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I corpi delle richieste della sezione Workflows (camelCase, come il resto delle rotte dei flussi).
//  I campi vuoti non si mandano; per svuotare la descrizione si manda una stringa vuota.
//

import Foundation

nonisolated struct AdminWorkflowCreate: Encodable, Sendable {
    static let maxName = 160
    static let maxDescription = 4000

    var name: String
    var description: String?
    /// Il grafo di un modello; senza, il flusso nasce vuoto.
    var graph: AdminWorkflowGraph?
}

/// PATCH: nome e descrizione. `revision` è obbligatoria.
nonisolated struct AdminWorkflowMetadataUpdate: Encodable, Sendable {
    var revision: Int
    var name: String?
    var description: String?

    var isEmpty: Bool { name == nil && description == nil }
}

/// Pubblica, archivia, ripristina: tutte vogliono solo la revisione letta.
nonisolated struct AdminWorkflowRevision: Encodable, Sendable {
    let revision: Int
}

nonisolated struct AdminWorkflowDuplicate: Encodable, Sendable {
    /// Senza nome sceglie il server.
    var name: String?
}
