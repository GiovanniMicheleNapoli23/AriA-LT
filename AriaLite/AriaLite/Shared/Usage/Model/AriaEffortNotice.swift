//
//  AriaEffortNotice.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  L'avviso sotto una risposta che è girata a un livello più basso di quello chiesto: tre frasi a seconda del motivo
//  (piano, tetto di spesa, altro). Il livello a cui è girata viene dal server (`aria.turn_usage`).
//

import Foundation

nonisolated enum AriaEffortNotice {
    /// `nil` se la risposta non è stata abbassata.
    static func degradedSentence(_ effort: AriaTurnUsage.Effort) -> String? {
        guard effort.degraded else { return nil }
        let requested = effort.requested.title
        let used = effort.effective.title
        return switch effort.reason {
        case "tier":
            String(localized: "You asked for \(requested), but it isn’t available on your plan, so this reply ran at \(used).")
        case "spend_cap":
            String(localized: "You asked for \(requested), but your company’s spending limit is reached, so this reply ran at \(used) on a lighter model.")
        default:
            String(localized: "You asked for \(requested), but it couldn’t be applied, so this reply ran at \(used).")
        }
    }
}
