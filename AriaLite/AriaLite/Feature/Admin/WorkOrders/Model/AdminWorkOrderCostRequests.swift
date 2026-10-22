//
//  AdminWorkOrderCostRequests.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I body dei costi di un ordine (WOLaborCreate, WOPartUsageCreate, WOPartUsageUpdate,
//  WOAdditionalCostCreate) e le categorie proposte per i costi aggiuntivi. Si codificano in snake_case
//  dalla chiamata; i campi `nil` non si mandano.
//

import Foundation

/// POST /v1/work-orders/{id}/labor.
nonisolated struct AdminWorkOrderLaborCreate: Encodable, Sendable {
    var worker: String?
    var startedAt: String?
    var durationMin: Double?
    var hourlyRate: Double?
}

/// POST /v1/work-orders/{id}/parts-used.
nonisolated struct AdminWorkOrderPartUsageCreate: Encodable, Sendable {
    var partId: String?
    var partCode: String?
    var quantity: Double?
    var unitCost: Double?
}

/// PATCH /v1/work-orders/{id}/parts-used/{entry_id}.
nonisolated struct AdminWorkOrderPartUsageUpdate: Encodable, Sendable {
    var quantity: Double?
    var unitCost: Double?
}

/// POST /v1/work-orders/{id}/additional-costs.
nonisolated struct AdminWorkOrderCostExtraCreate: Encodable, Sendable {
    var description: String?
    var value: Double?
    var costCategory: String?
}

/// Le categorie offerte per un costo aggiuntivo. Il backend accetta testo libero (nessun enum
/// nell'OpenAPI): una categoria che non è fra queste si mostra com'è.
nonisolated enum AdminWorkOrderCostCategory: String, CaseIterable, Hashable, Sendable {
    case transport, externalService = "external_service", rental, consumables, other

    var localized: String {
        switch self {
        case .transport: String(localized: "Transport")
        case .externalService: String(localized: "External service")
        case .rental: String(localized: "Rental")
        case .consumables: String(localized: "Consumables")
        case .other: String(localized: "Other")
        }
    }

    /// Il nome da mostrare per il valore scritto dal server.
    static func label(for raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        return Self(rawValue: raw)?.localized ?? raw
    }
}

/// Le tre sezioni della scheda costi.
nonisolated enum AdminWorkOrderCostKind: String, CaseIterable, Hashable, Sendable, Identifiable {
    case labor, parts, extra

    var id: String { rawValue }

    var title: String {
        switch self {
        case .labor: String(localized: "Labor")
        case .parts: String(localized: "Parts used")
        case .extra: String(localized: "Additional costs")
        }
    }

    var icon: String {
        switch self {
        case .labor: "person.badge.clock"
        case .parts: "shippingbox"
        case .extra: "plus.forwardslash.minus"
        }
    }

    var emptyText: String {
        switch self {
        case .labor: String(localized: "No labor logged yet.")
        case .parts: String(localized: "No parts used yet.")
        case .extra: String(localized: "No additional costs yet.")
        }
    }
}

/// Una riga già pronta da mostrare in una sezione dei costi.
nonisolated struct AdminWorkOrderCostRowItem: Identifiable, Hashable, Sendable {
    let kind: AdminWorkOrderCostKind
    let entryId: String
    let title: String
    let subtitle: String?
    let amount: String
    /// Solo i ricambi si modificano (PATCH quantità e costo unitario).
    let isEditable: Bool

    var id: String { "\(kind.rawValue)-\(entryId)" }
}

/// I totali in cima alla scheda.
nonisolated struct AdminWorkOrderCostTotals: Hashable, Sendable {
    let labor: String
    let parts: String
    let extra: String
    let total: String
}
