//
//  AdminScenarioKinds.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I valori a scelta della sezione (schede, tipo di scenario, stato delle chiusure, esito di una revisione,
//  filtri e ordinamenti) con le loro etichette. I valori del server restano testo: uno nuovo non rompe niente.
//

import Foundation

/// Le tre schede della pagina.
nonisolated enum AdminScenarioTab: String, CaseIterable, Identifiable, Sendable {
    case scenarios, reviews, closures

    var id: String { rawValue }

    var label: String {
        switch self {
        case .scenarios: String(localized: "Scenarios")
        case .reviews: String(localized: "Reviews")
        case .closures: String(localized: "Closures")
        }
    }
}

/// Il filtro `kind` di GET …/scenarios.
nonisolated enum AdminScenarioKind: String, CaseIterable, Identifiable, Sendable {
    case alarm, procedure

    var id: String { rawValue }

    var label: String {
        switch self {
        case .alarm: String(localized: "Alarms")
        case .procedure: String(localized: "Procedures")
        }
    }

    var systemImage: String {
        switch self {
        case .alarm: "bell.badge"
        case .procedure: "list.number"
        }
    }

    static func systemImage(for raw: String?) -> String {
        raw.flatMap(Self.init(rawValue:))?.systemImage ?? "point.3.connected.trianglepath.dotted"
    }
}

/// Come ordinare gli scenari: il server li dà già dal più sostenuto.
nonisolated enum AdminScenarioSort: String, CaseIterable, Identifiable, Sendable {
    case mostSessions, leastReliable, recentlyUpdated

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mostSessions: String(localized: "Most sessions")
        case .leastReliable: String(localized: "Least reliable")
        case .recentlyUpdated: String(localized: "Recently updated")
        }
    }
}

/// Il filtro `status` di GET …/procedure-closures; senza, il server li dà tutti.
nonisolated enum AdminScenarioClosureStatus: String, CaseIterable, Identifiable, Sendable {
    case unread, read, approved, reassigned, dismissed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .unread: String(localized: "Unread")
        case .read: String(localized: "Read")
        case .approved: String(localized: "Approved")
        case .reassigned: String(localized: "Reassigned")
        case .dismissed: String(localized: "Dismissed")
        }
    }

    static func label(for raw: String) -> String {
        Self(rawValue: raw)?.label ?? AdminScenarioLabel.humanized(raw)
    }
}

/// L'esito che un admin può dare a una procedura (SessionReviewRequest.outcome).
nonisolated enum AdminScenarioReviewOutcome: String, CaseIterable, Identifiable, Sendable {
    case resolved, partial, unresolved

    var id: String { rawValue }

    var label: String {
        switch self {
        case .resolved: String(localized: "Resolved")
        case .partial: String(localized: "Partially resolved")
        case .unresolved: String(localized: "Unresolved")
        }
    }

    var systemImage: String {
        switch self {
        case .resolved: "checkmark.circle.fill"
        case .partial: "circle.lefthalf.filled"
        case .unresolved: "xmark.circle.fill"
        }
    }
}

/// Quali sessioni mostrare nella scheda delle revisioni.
nonisolated enum AdminScenarioReviewFilter: String, CaseIterable, Identifiable, Sendable {
    case all, awaiting, reviewed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: String(localized: "All")
        case .awaiting: String(localized: "Awaiting review")
        case .reviewed: String(localized: "Reviewed")
        }
    }
}

/// Il tono di un'etichetta (il colore lo sceglie la vista).
nonisolated enum AdminScenarioTone: Sendable {
    case positive, warning, negative, info, neutral
}
