//
//  AdminWorkOrderActivityModels.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Messaggi e storico delle modifiche di un ordine (GET /messages, GET /v1/audit-log). Le risposte dei
//  messaggi non sono documentate: si legge tutto con tolleranza, solo l'id è obbligatorio.
//

import Foundation

/// Le due viste della scheda Attività.
nonisolated enum AdminWorkOrderActivitySection: String, CaseIterable, Identifiable, Sendable {
    case messages, history

    var id: Self { self }

    var title: String {
        switch self {
        case .messages: String(localized: "Messages")
        case .history: String(localized: "History")
        }
    }
}

/// Un elenco che arriva come array semplice o dentro un oggetto (`items`, `data`, `messages`, `attachments`).
/// Le righe che non si leggono si scartano (AriaLossyArray).
nonisolated struct AdminWorkOrderActivityList<Element: Decodable & Sendable>: Decodable, Sendable {
    var items: [Element]

    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    init(from decoder: any Decoder) throws {
        if let rows = try? AriaLossyArray<Element>(from: decoder) {
            items = rows.items
            return
        }
        let c = try decoder.container(keyedBy: Key.self)
        for name in ["items", "data", "messages", "attachments", "results"] {
            if let rows = try? c.decode(AriaLossyArray<Element>.self, forKey: Key(stringValue: name)) {
                items = rows.items
                return
            }
        }
        items = []
    }
}

// MARK: Messaggi

nonisolated struct AdminWorkOrderMessage: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    var author: String?
    var content: String
    var createdAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id, underscoreId = "_id", messageId
        case author, authorName, userName, createdBy
        case content, message, text, body
        case createdAt, timestamp, sentAt
    }

    init(from decoder: any Decoder) throws {
        let f = try AdminWorkOrderFields(decoder, keyedBy: CodingKeys.self)
        guard let id = f.id(.id) ?? f.id(.underscoreId) ?? f.id(.messageId) else {
            throw DecodingError.keyNotFound(CodingKeys.id, .init(codingPath: decoder.codingPath, debugDescription: "id"))
        }
        self.id = id
        author = f.text(.author) ?? f.text(.authorName) ?? f.text(.userName) ?? f.text(.createdBy)
        content = f.value(String.self, .content) ?? f.value(String.self, .message)
            ?? f.value(String.self, .text) ?? f.value(String.self, .body) ?? ""
        createdAt = f.date(.createdAt) ?? f.date(.timestamp) ?? f.date(.sentAt)
    }
}

/// Body di POST /v1/work-orders/{id}/messages (WorkOrderMessageCreate).
nonisolated struct AdminWorkOrderMessageCreate: Encodable, Sendable {
    let author: String
    let content: String
    let workOrderId: String
}

// MARK: Storico

/// AuditLogPageResponse.
nonisolated struct AdminWorkOrderAuditPage: Decodable, Sendable {
    var items: [AdminWorkOrderAuditEntry]
    var total: Int?

    private enum CodingKeys: String, CodingKey { case items, total }

    init(from decoder: any Decoder) throws {
        let f = try AdminWorkOrderFields(decoder, keyedBy: CodingKeys.self)
        items = f.array(AdminWorkOrderAuditEntry.self, .items)
        total = f.int(.total)
    }
}

/// AuditLogResponse: chi (`userId`), cosa (`action`), quali campi (`changes`, una stringa JSON) e quando.
nonisolated struct AdminWorkOrderAuditEntry: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    var action: String?
    var userId: String?
    var displayName: String?
    var changes: [AdminWorkOrderAuditChange]
    /// `changes` quando non è JSON: si mostra così com'è.
    var changesText: String?
    var createdAt: Date?

    private enum CodingKeys: String, CodingKey { case id, action, userId, displayName, changes, createdAt }

    init(from decoder: any Decoder) throws {
        let f = try AdminWorkOrderFields(decoder, keyedBy: CodingKeys.self)
        guard let id = f.id(.id) else {
            throw DecodingError.keyNotFound(CodingKeys.id, .init(codingPath: decoder.codingPath, debugDescription: "id"))
        }
        self.id = id
        action = f.text(.action)
        userId = f.text(.userId)
        displayName = f.text(.displayName)
        createdAt = f.date(.createdAt)
        let raw = f.value(AriaJSON.self, .changes)
        changes = AdminWorkOrderAuditChange.parse(raw)
        changesText = changes.isEmpty ? raw?.nonEmptyString : nil
    }
}

/// Un campo cambiato: valore prima e dopo, quando il backend li registra.
nonisolated struct AdminWorkOrderAuditChange: Sendable, Hashable {
    let field: String
    let old: AriaJSON?
    let new: AriaJSON?

    /// Forme accettate (il formato non è documentato):
    /// `{campo: {old, new}}` (o from/to, before/after), `{campo: [old, new]}`, `{before: {…}, after: {…}}`,
    /// `{campo: valore}`. Se `changes` è una stringa, prima si rilegge come JSON.
    static func parse(_ raw: AriaJSON?) -> [AdminWorkOrderAuditChange] {
        guard var json = raw else { return [] }
        if case .string(let text) = json {
            guard let data = text.data(using: .utf8), let inner = try? JSONDecoder().decode(AriaJSON.self, from: data) else {
                return []
            }
            json = inner
        }
        guard let object = json.objectValue else { return [] }
        // Due istantanee intere: si confrontano campo per campo.
        let pairs: [(String, String)] = [("before", "after"), ("old", "new"), ("previous", "current")]
        for (oldKey, newKey) in pairs {
            if let before = object[oldKey]?.objectValue, let after = object[newKey]?.objectValue {
                let keys = Set(before.keys).union(after.keys).sorted()
                return keys.compactMap { key in
                    before[key] == after[key] ? nil : AdminWorkOrderAuditChange(field: key, old: before[key], new: after[key])
                }.filter { !isNoise($0.field) }
            }
        }
        return object.keys.sorted().filter { !isNoise($0) }.map { key in
            let value = object[key] ?? .null
            if let inner = value.objectValue {
                let old = inner["old"] ?? inner["from"] ?? inner["before"] ?? inner["old_value"] ?? inner["oldValue"]
                let new = inner["new"] ?? inner["to"] ?? inner["after"] ?? inner["new_value"] ?? inner["newValue"]
                if old != nil || new != nil { return AdminWorkOrderAuditChange(field: key, old: old, new: new) }
            }
            if case .array(let items) = value, items.count == 2 {
                return AdminWorkOrderAuditChange(field: key, old: items[0], new: items[1])
            }
            return AdminWorkOrderAuditChange(field: key, old: nil, new: value)
        }
    }

    /// Campi che cambiano a ogni salvataggio: non dicono niente.
    private static func isNoise(_ field: String) -> Bool {
        ["updated_at", "updatedAt", "_id", "id"].contains(field)
    }
}
