//
//  AriaChatStyle+Display.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Come si presenta lo stile di risposta (menu "+" e pillola nel composer), e il dettaglio del
//  contatore della memoria che decide il testo del popover.
//

import Foundation

extension AriaChatStyle {
    var title: String {
        switch self {
        case .auto: String(localized: "Auto")
        case .detailed: String(localized: "Detailed")
        case .compact: String(localized: "Compact (operator)")
        }
    }

    var shortTitle: String {
        switch self {
        case .auto: String(localized: "Auto")
        case .detailed: String(localized: "Detailed")
        case .compact: String(localized: "Compact")
        }
    }

    var icon: String {
        switch self {
        case .auto: "wand.and.sparkles"
        case .detailed: "text.alignleft"
        case .compact: "text.line.first.and.arrowtriangle.forward"
        }
    }
}

extension AriaContextUsage {
    /// Manuali e istruzioni che Aria legge occupano almeno metà dello spazio: compattare non lo libera.
    var isMostlyOverhead: Bool {
        guard let overheadTokens, usedTokens > 0 else { return false }
        return Double(overheadTokens) / Double(usedTokens) >= 0.5
    }
}
