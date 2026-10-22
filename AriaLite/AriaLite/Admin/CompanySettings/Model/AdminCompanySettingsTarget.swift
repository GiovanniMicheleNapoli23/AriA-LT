//
//  AdminCompanySettingsTarget.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Cosa si sta per cancellare: tutta l'azienda o uno stabilimento. Il nome è quello che l'utente deve
//  riscrivere per confermare, esattamente.
//

import Foundation

nonisolated enum AdminCompanySettingsTarget: Equatable, Sendable, Identifiable {
    case company(id: String, name: String)
    case plant(id: String, name: String)

    var id: String {
        switch self {
        case .company(let id, _): "company-\(id)"
        case .plant(let id, _): "plant-\(id)"
        }
    }

    /// Il nome che va riscritto per confermare.
    var name: String {
        switch self {
        case .company(_, let name), .plant(_, let name): name
        }
    }

    var title: String {
        switch self {
        case .company: String(localized: "Delete all company data")
        case .plant: String(localized: "Delete plant data")
        }
    }

    /// Spiega in parole semplici cosa sparisce.
    var explanation: String {
        switch self {
        case .company(_, let name):
            String(localized:
                "Deletes all operational data of the company \(name) across every plant. Control-plane data is kept.")
        case .plant(_, let name):
            String(localized:
                "Deletes the operational data of the plant \(name). The other plants of the company are not touched.")
        }
    }

    /// Il nome scritto corrisponde (spazi ai bordi ignorati, maiuscole e minuscole contano).
    /// Un nome vuoto non corrisponde mai.
    func matches(_ typed: String) -> Bool {
        let expected = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !expected.isEmpty else { return false }
        return typed.trimmingCharacters(in: .whitespacesAndNewlines) == expected
    }
}
