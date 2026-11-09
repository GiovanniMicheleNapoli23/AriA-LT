//
//  AdminDocumentConflicts.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Legge la risposta di POST /v1/documents/upload/conflicts, `{stringa: [stringhe]}` dal significato
//  non documentato: un nome scelto è in conflitto se compare come chiave con una lista non vuota
//  o dentro una qualsiasi lista. Il confronto ignora maiuscole e minuscole.
//

import Foundation

nonisolated enum AdminDocumentConflicts {
    /// I nomi di `requested` già presenti nello stabilimento.
    static func names(in response: AriaJSON, requested: [String]) -> Set<String> {
        var found = Set<String>()
        for (key, value) in response.objectValue ?? [:] {
            let values = value.arrayValue.compactMap(\.stringValue)
            if !values.isEmpty { found.insert(key.lowercased()) }
            values.forEach { found.insert($0.lowercased()) }
        }
        // Un array semplice di nomi, nel caso il server cambi forma.
        response.arrayValue.compactMap(\.stringValue).forEach { found.insert($0.lowercased()) }
        return Set(requested.filter { found.contains($0.lowercased()) })
    }
}
