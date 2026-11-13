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

/// Ruolo al passo Profilo (obbligatorio, come sulla web).
nonisolated enum AriaJobRole: String, CaseIterable, Identifiable, Sendable {
    case plantManager = "plant_manager"
    case maintenanceEngineer = "maintenance_engineer"
    case technician
    case operationsLead = "operations_lead"
    case other

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .plantManager: "Site manager"
        case .maintenanceEngineer: "Maintenance engineer"
        case .technician: "Technician"
        case .operationsLead: "Operations lead"
        case .other: "Other"
        }
    }
}

/// Settore al passo Azienda (facoltativo: senza scelta non si manda).
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
        case .food: "Food & beverage"
        case .pharma: "Pharma"
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

    var title: LocalizedStringResource {
        switch self {
        case .tiny: "1–10 people"
        case .small: "11–50 people"
        case .medium: "51–200 people"
        case .large: "201–1000 people"
        case .huge: "More than 1000 people"
        }
    }
}

/// La lingua del telefono per `preferredLocale`: due lettere, `en` se non si sa. L'email di benvenuto è in italiano
/// per `it`, in inglese per tutto il resto.
nonisolated enum AriaSignUpLocale {
    static var current: String {
        let preferred = Locale.preferredLanguages.first.map(Locale.init(identifier:)) ?? .current
        return preferred.language.languageCode?.identifier ?? "en"
    }
}
