//
//  AdminAuditLogChange.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un campo cambiato in una modifica: valore prima e dopo. Il formato di `changes` non è documentato,
//  quindi si leggono le forme che il backend usa in pratica.
//

import Foundation

/// Un campo cambiato: prima e dopo, quando il backend li registra.
nonisolated struct AdminAuditLogChange: Sendable, Hashable, Identifiable {
    let field: String
    let old: AriaJSON?
    let new: AriaJSON?

    var id: String { field }

    /// Forme accettate:
    /// `{campo: {old, new}}` (anche from/to, before/after), `{campo: [prima, dopo]}`,
    /// `{before: {…}, after: {…}}` (due istantanee intere, confrontate campo per campo), `{campo: valore}`.
    /// Se `changes` è una stringa, prima si rilegge come JSON. Chiavi di servizio come `updated_at` non si mostrano.
    static func parse(_ raw: AriaJSON?) -> [AdminAuditLogChange] {
        guard var json = raw else { return [] }
        if case .string(let text) = json {
            guard let data = text.data(using: .utf8),
                  let inner = try? JSONDecoder().decode(AriaJSON.self, from: data) else { return [] }
            json = inner
        }
        guard let object = json.objectValue else { return [] }

        let snapshotPairs: [(String, String)] = [("before", "after"), ("old", "new"), ("previous", "current")]
        for (oldKey, newKey) in snapshotPairs {
            if let before = object[oldKey]?.objectValue, let after = object[newKey]?.objectValue {
                let keys = Set(before.keys).union(after.keys).sorted()
                return keys.compactMap { key in
                    before[key] == after[key] ? nil : AdminAuditLogChange(field: key, old: before[key], new: after[key])
                }.filter { !isNoise($0.field) }
            }
        }

        return object.keys.sorted().filter { !isNoise($0) }.map { key in
            let value = object[key] ?? .null
            if let inner = value.objectValue {
                let old = inner["old"] ?? inner["from"] ?? inner["before"] ?? inner["old_value"] ?? inner["oldValue"]
                let new = inner["new"] ?? inner["to"] ?? inner["after"] ?? inner["new_value"] ?? inner["newValue"]
                if old != nil || new != nil { return AdminAuditLogChange(field: key, old: old, new: new) }
            }
            if case .array(let items) = value, items.count == 2 {
                return AdminAuditLogChange(field: key, old: items[0], new: items[1])
            }
            return AdminAuditLogChange(field: key, old: nil, new: value)
        }
    }

    /// Campi che cambiano a ogni salvataggio o identificano la riga: non dicono niente di nuovo.
    private static func isNoise(_ field: String) -> Bool {
        ["updated_at", "updatedAt", "_id", "id"].contains(field)
    }
}
