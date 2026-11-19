//
//  AdminUsageNoticeThreshold.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La soglia di un avviso scritta come percentuale (contratto 5.4): 60 → quota 0.6, 62.5 → 0.625, 100 → 1. I crediti
//  del giorno e il limite che si avvicina prendono da 1 a 100, i crediti extra 100 o più. Una soglia non valida non si
//  manda e blocca il salvataggio finché non si corregge.
//

import Foundation

/// Perché una soglia scritta non si può salvare.
nonisolated enum AdminUsageNoticeThresholdError: Sendable, Equatable {
    /// "Enter a percentage from 1 to 100." (crediti del giorno e limite che si avvicina)
    case range
    /// "Enter 100% or more." (crediti extra)
    case overage

    var text: String {
        switch self {
        case .range:
            return String(localized: "usage.noticeSettings.thresholdRange", defaultValue: "Enter a percentage from 1 to 100.")
        case .overage:
            // Il "100%" è un argomento: un `%` nel testo tradotto non si confonde mai con un segnaposto.
            let hundred = "100%"
            return String(localized: "usage.noticeSettings.thresholdOverage", defaultValue: "Enter \(hundred) or more.")
        }
    }

    /// L'errore da mostrare per un avviso.
    static func error(for notice: AriaNoticeKey) -> AdminUsageNoticeThresholdError {
        notice == .overage ? .overage : .range
    }
}

nonisolated enum AdminUsageNoticeThreshold {
    nonisolated enum Check: Sendable, Equatable {
        /// La percentuale scritta (60, 62.5); la quota da mandare è `percent / 100`.
        case valid(percent: Decimal)
        case invalid(AdminUsageNoticeThresholdError)
    }

    static func check(_ text: String, notice: AriaNoticeKey) -> Check {
        let failure = Check.invalid(.error(for: notice))
        guard let percent = AdminUsageAmountInput.parse(text) else { return failure }
        switch notice {
        case .overage: return percent >= 100 ? .valid(percent: percent) : failure
        case .dailyAllowance, .capApproaching: return percent >= 1 && percent <= 100 ? .valid(percent: percent) : failure
        }
    }
}
