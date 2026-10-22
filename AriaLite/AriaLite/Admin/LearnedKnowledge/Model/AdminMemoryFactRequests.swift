//
//  AdminMemoryFactRequests.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I body delle scritture sui fatti, in camelCase come vuole il server. Un campo `nil` non si manda:
//  per la modifica vuol dire "non toccare", mentre una stringa vuota toglie contesto o categoria.
//

import Foundation

/// POST …/memory-facts. `plantId` è obbligatorio.
nonisolated struct AdminMemoryFactCreate: Encodable, Sendable {
    let content: String
    let context: String?
    let category: String?
    let plantId: String

    static let maxContent = 2000
    static let maxContext = 200
}

/// PATCH …/memory-facts/{id}: approva o rifiuta, con l'eventuale testo corretto.
nonisolated struct AdminMemoryFactModeration: Encodable, Sendable {
    enum Action: String, Encodable, Sendable { case approve, reject }
    let action: Action
    var content: String? = nil
    var context: String? = nil
}

/// PUT …/memory-facts/{id}: solo i campi cambiati.
nonisolated struct AdminMemoryFactUpdate: Encodable, Sendable {
    var content: String?
    var context: String?
    var category: String?

    var isEmpty: Bool { content == nil && context == nil && category == nil }
}
