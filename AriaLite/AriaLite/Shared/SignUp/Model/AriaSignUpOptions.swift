//
//  AriaSignUpOptions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 11/11/26.
//
//  Le scelte dei moduli dell'iscrizione, con i valori esatti della web (il backend non li controlla e salva quello
//  che riceve: devono essere gli stessi perché web e app costruiscano lo stesso profilo e la stessa azienda).
//

import Foundation

/// Ruolo al passo Profilo (obbligatorio, come sulla web). Con "Altro" si manda il testo scritto, non `other`.
nonisolated enum AriaJobRole: String, CaseIterable, Identifiable, Sendable {
    case plantManager = "plant_manager"
    case maintenanceEngineer = "maintenance_engineer"
    case technician
    case operationsLead = "operations_lead"
    case other

    var id: String { rawValue }

    /// Le etichette della web; in inglese "site", mai "plant".
    var title: LocalizedStringResource {
        switch self {
        case .plantManager: "Site Manager"
        case .maintenanceEngineer: "Maintenance Engineer"
        case .technician: "Technician"
        case .operationsLead: "Operations Lead"
        case .other: "Other"
        }
    }

    /// Il ruolo salvato com'è: un valore della lista, oppure il testo scritto sotto "Altro" (la web apre "Altro" già
    /// compilato). Vuoto: nessuna scelta.
    static func choice(saved: String?) -> (role: AriaJobRole?, otherText: String) {
        let saved = saved?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !saved.isEmpty else { return (nil, "") }
        if let role = AriaJobRole(rawValue: saved), role != .other { return (role, "") }
        return (.other, saved == AriaJobRole.other.rawValue ? "" : saved)
    }
}

/// Il valore di una scelta con "Altro": quello della lista, o sotto "Altro" il testo scritto (al massimo 80 caratteri,
/// come la web). Vuoto finché non c'è.
nonisolated enum AriaOtherChoice {
    static let maxLength = 80

    static func value(_ raw: String?, isOther: Bool, otherText: String) -> String {
        guard let raw else { return "" }
        return isOther ? String(otherText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxLength)) : raw
    }
}

/// Settore al passo Azienda: obbligatorio come sulla web; con "Altro" si manda il testo scritto.
nonisolated enum AriaCompanyIndustry: String, CaseIterable, Identifiable, Sendable {
    case manufacturing
    case energy
    case automotive
    case food
    case pharma
    case other

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .manufacturing: "Manufacturing"
        case .energy: "Energy"
        case .automotive: "Automotive"
        case .food: "Food & Beverage"
        case .pharma: "Pharmaceutical"
        case .other: "Other"
        }
    }
}

/// Dimensione al passo Azienda (facoltativa). I valori usano il trattino lungo U+2013, non il segno meno.
nonisolated enum AriaCompanySize: String, CaseIterable, Identifiable, Sendable {
    case tiny = "1\u{2013}10"
    case small = "11\u{2013}50"
    case medium = "51\u{2013}200"
    case large = "201\u{2013}1000"
    case huge = "1000+"

    var id: String { rawValue }

    /// Come la web: solo i numeri.
    var title: String { rawValue }
}

/// La lingua del telefono per `preferredLocale`: due lettere, `en` se non si sa. L'email di benvenuto è in italiano
/// per `it`, in inglese per tutto il resto.
nonisolated enum AriaSignUpLocale {
    static var current: String {
        let preferred = Locale.preferredLanguages.first.map(Locale.init(identifier:)) ?? .current
        return preferred.language.languageCode?.identifier ?? "en"
    }
}
