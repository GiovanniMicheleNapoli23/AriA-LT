//
//  AriaAvailability+Color.swift
//  AriaLite
//
//  Created by Giovanni Michele on 08/10/26.
//
//  Il colore di ciascuna disponibilità dell'operatore: il pallino nella riga delle impostazioni e il simbolo
//  nella pagina delle scelte.
//

import SwiftUI

extension AriaAvailability {
    var color: Color {
        switch self {
        case .available: .green
        case .busy: .orange
        case .offDuty: .gray
        }
    }
}
