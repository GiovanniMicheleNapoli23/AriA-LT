//
//  AdminSparePartKinds.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Categoria (SparePartCategory) e stato (EntityStatus) di un ricambio. Un valore che il backend
//  aggiunge dopo diventa `unknown` ("Other"): si mostra ma non si rimanda mai al server.
//

import Foundation

nonisolated enum AdminSparePartCategory: String, CaseIterable, Sendable, Hashable {
    case bearing, belt, filter, seal, motor, coupling, electrical, hydraulic, pneumatic
    case sensor, safety, lubricant, gasket, general
    case unknown

    init(wire: String) { self = Self(rawValue: wire.lowercased()) ?? .unknown }

    /// Le categorie che si possono scegliere nel modulo.
    static var selectable: [Self] { allCases.filter { $0 != .unknown } }

    var localized: String {
        switch self {
        case .bearing: String(localized: "Bearing")
        case .belt: String(localized: "Belt")
        case .filter: String(localized: "Filter")
        case .seal: String(localized: "Seal")
        case .motor: String(localized: "Motor")
        case .coupling: String(localized: "Coupling")
        case .electrical: String(localized: "Electrical")
        case .hydraulic: String(localized: "Hydraulic")
        case .pneumatic: String(localized: "Pneumatic")
        case .sensor: String(localized: "Sensor")
        case .safety: String(localized: "Safety")
        case .lubricant: String(localized: "Lubricant")
        case .gasket: String(localized: "Gasket")
        case .general: String(localized: "General")
        case .unknown: String(localized: "Other")
        }
    }
}

nonisolated enum AdminSparePartStatus: String, CaseIterable, Sendable, Hashable {
    case staged, draft, approved, rejected, superseded
    case unknown

    init(wire: String) { self = Self(rawValue: wire.lowercased()) ?? .unknown }

    static var selectable: [Self] { allCases.filter { $0 != .unknown } }

    /// Lo stato di un ricambio nuovo (default di SparePartCreate).
    static let newPartDefault = Self.draft

    var localized: String {
        switch self {
        case .staged: String(localized: "Staged")
        case .draft: String(localized: "Draft")
        case .approved: String(localized: "Approved")
        case .rejected: String(localized: "Rejected")
        case .superseded: String(localized: "Superseded")
        case .unknown: String(localized: "Other")
        }
    }
}
