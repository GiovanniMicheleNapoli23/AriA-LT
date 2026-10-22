//
//  AdminExtractionKind.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I quattro tipi di dato che l'AI estrae dai documenti, uno per segmento della pagina: asset, allarmi,
//  piani di manutenzione e ricambi. Ognuno con etichette, icona e il verbo della sua rotta AI.
//

import Foundation

nonisolated enum AdminExtractionKind: String, CaseIterable, Identifiable, Sendable, Hashable {
    case assets, alarms, maintenancePlans, spareParts

    var id: String { rawValue }

    /// Etichetta breve: sta nel controllo segmentato anche su iPhone.
    var shortTitle: String {
        switch self {
        case .assets: String(localized: "Assets")
        case .alarms: String(localized: "Alarms")
        case .maintenancePlans: String(localized: "Plans")
        case .spareParts: String(localized: "Parts")
        }
    }

    var title: String {
        switch self {
        case .assets: String(localized: "Assets")
        case .alarms: String(localized: "Alarms")
        case .maintenancePlans: String(localized: "Maintenance plans")
        case .spareParts: String(localized: "Spare parts")
        }
    }

    var systemImage: String {
        switch self {
        case .assets: "gearshape.2"
        case .alarms: "bell.badge"
        case .maintenancePlans: "calendar.badge.clock"
        case .spareParts: "shippingbox"
        }
    }

    /// Asset e ricambi hanno `ai-analyze`, allarmi e piani `ai-improve`.
    var aiTitle: String {
        switch self {
        case .assets, .spareParts: String(localized: "Analyze with AI")
        case .alarms, .maintenancePlans: String(localized: "Improve with AI")
        }
    }

    /// Solo asset e allarmi hanno POST bulk-approve; piani e ricambi si approvano uno per uno (PATCH).
    var hasBulkApprove: Bool { self == .assets || self == .alarms }
}

/// Gli stati di EntityStatus che vogliono una revisione: le bozze dell'estrazione e quelle in attesa.
nonisolated enum AdminExtractionStatus {
    static let pending = ["draft", "staged"]
    static let approved = "approved"
    static let rejected = "rejected"
}
