//
//  AdminWorkOrderFormStep.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I passi della creazione di un ordine, una pagina ciascuno: cosa, che tipo, dove, chi e quando, riepilogo.
//  Il riepilogo è fatto di gruppi, uno per passo, con le righe già scritte.
//

import Foundation

nonisolated enum AdminWorkOrderFormStep: Int, CaseIterable, Identifiable, Sendable {
    case details, classification, location, assignment, review

    var id: Self { self }

    var title: String {
        switch self {
        case .details: String(localized: "Details")
        case .classification: String(localized: "Classification")
        case .location: String(localized: "Location")
        case .assignment: String(localized: "Assignment")
        case .review: String(localized: "Review")
        }
    }

    var subtitle: String {
        switch self {
        case .details: String(localized: "What needs to be done?")
        case .classification: String(localized: "How urgent is it, and what kind of work?")
        case .location: String(localized: "Where does the work happen?")
        case .assignment: String(localized: "Who does it, and when?")
        case .review: String(localized: "Check everything, then create the order.")
        }
    }

    var systemImage: String {
        switch self {
        case .details: "text.alignleft"
        case .classification: "flag"
        case .location: "mappin.and.ellipse"
        case .assignment: "person.2"
        case .review: "checkmark.circle"
        }
    }
}

/// Le righe del riepilogo di un passo: tocca il gruppo per tornarci.
nonisolated struct AdminWorkOrderFormSummaryGroup: Identifiable, Sendable {
    let step: AdminWorkOrderFormStep
    let rows: [AdminWorkOrderFormSummaryRow]
    /// Cosa manca in quel passo; `nil` se è a posto.
    let issue: String?

    var id: AdminWorkOrderFormStep { step }
}

nonisolated struct AdminWorkOrderFormSummaryRow: Identifiable, Sendable {
    let label: String
    let value: String

    var id: String { label }
}
