//
//  AdminExtractionTone.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  I colori spenti della revisione: lo stato di un elemento e la confidenza dell'AI (sotto il 50% da
//  guardare con attenzione, sotto l'80% con un occhio, sopra va bene).
//

import SwiftUI

enum AdminExtractionTone {
    static func status(_ raw: String) -> Color {
        switch AdminAssetStatus(rawValue: raw) {
        case .approved: .liteSuccess
        case .draft: .liteWarning
        case .staged: .liteAccent
        case .rejected: .liteDanger
        case .superseded, nil: .secondary
        }
    }

    static func confidence(_ value: Double) -> Color {
        switch value {
        case ..<0.5: .liteDanger
        case ..<0.8: .liteWarning
        default: .liteSuccess
        }
    }

    static func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }
}
