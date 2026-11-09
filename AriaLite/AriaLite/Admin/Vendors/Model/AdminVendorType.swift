//
//  AdminVendorType.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il tipo di fornitore è testo libero: "OEM", "spare_parts" e "Spare parts" sono lo stesso tipo.
//  La chiave li unisce (senza maiuscole né separatori), l'etichetta li rende leggibili.
//

import Foundation

/// Un tipo presente nell'elenco, con quanti fornitori lo hanno: una voce della fila di filtri.
nonisolated struct AdminVendorTypeOption: Identifiable, Hashable, Sendable {
    let key: String
    let label: String
    let count: Int

    var id: String { key }
}

nonisolated enum AdminVendorType {
    /// "Spare_Parts " → "spare parts": per confrontare tipi scritti in modi diversi.
    static func key(_ raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    /// "spare_parts" → "Spare Parts". Un testo che ha già maiuscole ("OEM", "Tier 1") resta com'è.
    static func label(_ raw: String) -> String {
        let spaced = raw.replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return spaced == spaced.lowercased() ? spaced.capitalized : spaced
    }
}

extension AdminVendor {
    /// `nil` se il fornitore non ha un tipo.
    var typeKey: String? { vendorType.map(AdminVendorType.key) }

    var typeLabel: String? { vendorType.map(AdminVendorType.label) }
}
