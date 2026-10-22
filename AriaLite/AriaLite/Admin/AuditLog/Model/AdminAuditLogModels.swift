//
//  AdminAuditLogModels.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le risposte di GET /v1/audit-log (AuditLogPageResponse, AuditLogResponse) e di GET /v1/users. Tutto opzionale
//  tranne l'id, che si ricostruisce dal contenuto se il server non lo manda. Le date arrivano come stringhe.
//

import Foundation

/// AuditLogPageResponse: una pagina di modifiche, con il totale quando il server lo dà.
nonisolated struct AdminAuditLogPage: Decodable, Sendable {
    var items: [AdminAuditLogEntry]
    var total: Int?

    private enum CodingKeys: String, CodingKey { case items, total }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decode(AriaLossyArray<AdminAuditLogEntry>.self, forKey: .items))?.items ?? []
        total = try? c.decodeIfPresent(Int.self, forKey: .total)
    }
}

/// AuditLogResponse: chi (`userId`), cosa (`action`), su che cosa (`entityType`, `entityId`, `displayName`),
/// quali campi (`changes`) e quando.
nonisolated struct AdminAuditLogEntry: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    var entityType: String?
    var entityId: String?
    var displayName: String?
    var action: String?
    var userId: String?
    var createdAt: Date?
    /// I campi cambiati, letti da `changes` (stringa JSON o oggetto).
    var changes: [AdminAuditLogChange]
    /// `changes` quando non ha una forma riconosciuta: si mostra com'è.
    var changesNote: String?

    private enum CodingKeys: String, CodingKey {
        case id, entityType, entityId, displayName, action, userId, createdAt, changes
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        entityType = try? c.decodeIfPresent(String.self, forKey: .entityType)
        entityId = try? c.decodeIfPresent(String.self, forKey: .entityId)
        displayName = try? c.decodeIfPresent(String.self, forKey: .displayName)
        action = try? c.decodeIfPresent(String.self, forKey: .action)
        userId = try? c.decodeIfPresent(String.self, forKey: .userId)
        let rawDate = try? c.decodeIfPresent(String.self, forKey: .createdAt)
        createdAt = AriaDate.parse(rawDate)
        let raw = try? c.decodeIfPresent(AriaJSON.self, forKey: .changes)
        changes = AdminAuditLogChange.parse(raw)
        changesNote = changes.isEmpty ? Self.note(from: raw) : nil
        // Senza id il server non dice chi è la riga: si ricava dal contenuto (stabile fra due caricamenti).
        if let rawId = try? c.decodeIfPresent(String.self, forKey: .id), !rawId.isEmpty {
            id = rawId
        } else {
            id = [rawDate, action, entityType, entityId, userId, raw?.compactDescription]
                .map { $0 ?? "" }.joined(separator: "|")
        }
    }

    /// Il testo di `changes` quando non ha una forma riconosciuta e non è vuoto.
    private static func note(from raw: AriaJSON?) -> String? {
        switch raw {
        case nil, .null?: nil
        case .string(let text)?:
            text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
        case let value?:
            ["{}", "[]"].contains(value.compactDescription) ? nil : value.compactDescription
        }
    }
}

/// Un utente di GET /v1/users: il nome per mostrare chi ha fatto la modifica.
nonisolated struct AdminAuditLogUser: Decodable, Sendable {
    let id: String?
    let email: String?
    let fullName: String?
}
