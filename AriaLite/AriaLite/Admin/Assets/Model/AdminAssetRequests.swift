//
//  AdminAssetRequests.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Body di creazione e modifica di un asset (AssetCreate / AssetUpdate) e di una PATCH in generale.
//  La modifica manda solo i campi cambiati: un campo svuotato va come `null`, uno non toccato non va.
//

import Foundation

/// POST /v1/assets. I campi `nil` non si scrivono (Encodable sintetizzato): decide il default del server.
nonisolated struct AdminAssetCreate: Encodable, Sendable {
    var tag: String
    var name: String
    var assetType: String
    var status: String
    var plantId: String
    var zone: String?
    var powerKw: Double?
    var description: String?
    var manufacturer: String?
    var model: String?
    var serialNumber: String?
    var driveTag: String?
    var driveType: String?
    var notes: String?
}

/// Body di una PATCH (asset o fermo): chiavi già in snake_case, che restano uguali anche se l'encoder
/// converte le chiavi dei dizionari.
nonisolated struct AdminPatchBody: Sendable {
    private(set) var fields: [String: AriaJSON] = [:]

    var isEmpty: Bool { fields.isEmpty }

    /// Testo: vuoto vuol dire "togli il valore" (null), uguale all'originale vuol dire "non mandare".
    mutating func text(_ key: String, _ value: String, was original: String?) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != (original ?? "") else { return }
        fields[key] = trimmed.isEmpty ? .null : .string(trimmed)
    }

    /// Valore qualsiasi, mandato solo se diverso dall'originale.
    mutating func value(_ key: String, _ value: AriaJSON, was original: AriaJSON) {
        guard value != original else { return }
        fields[key] = value
    }

    mutating func number(_ key: String, _ value: Double?, was original: Double?) {
        guard value != original else { return }
        fields[key] = value.map(AriaJSON.number) ?? .null
    }
}
