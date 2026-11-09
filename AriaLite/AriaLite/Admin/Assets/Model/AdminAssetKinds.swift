//
//  AdminAssetKinds.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Tipi (AssetType) e stati (EntityStatus) di un asset, con etichetta e icona.
//  I valori sconosciuti non si perdono: l'asset tiene il valore grezzo e qui si mostra com'è.
//

import Foundation

nonisolated enum AdminAssetType: String, CaseIterable, Sendable, Hashable, Identifiable {
    case motor, sensor, inverter, pump, valve, burner

    var id: String { rawValue }

    var label: String {
        switch self {
        case .motor: String(localized: "Motor")
        case .sensor: String(localized: "Sensor")
        case .inverter: String(localized: "Inverter")
        case .pump: String(localized: "Pump")
        case .valve: String(localized: "Valve")
        case .burner: String(localized: "Burner")
        }
    }

    var systemImage: String {
        switch self {
        case .motor: "gearshape.2"
        case .sensor: "dot.radiowaves.left.and.right"
        case .inverter: "bolt.fill"
        case .pump: "drop.fill"
        case .valve: "dial.medium"
        case .burner: "flame.fill"
        }
    }

    /// Etichetta di un valore grezzo: un tipo nuovo del backend si mostra leggibile, non si scarta.
    static func label(for raw: String) -> String {
        Self(rawValue: raw)?.label ?? raw.replacingOccurrences(of: "_", with: " ").capitalized
    }

    static func systemImage(for raw: String?) -> String {
        raw.flatMap(Self.init(rawValue:))?.systemImage ?? "shippingbox"
    }
}

nonisolated enum AdminAssetStatus: String, CaseIterable, Sendable, Hashable, Identifiable {
    case approved, draft, staged, rejected, superseded

    var id: String { rawValue }

    var label: String {
        switch self {
        case .approved: String(localized: "Approved")
        case .draft: String(localized: "Draft")
        case .staged: String(localized: "Staged")
        case .rejected: String(localized: "Rejected")
        case .superseded: String(localized: "Superseded")
        }
    }

    static func label(for raw: String) -> String {
        Self(rawValue: raw)?.label ?? raw.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
