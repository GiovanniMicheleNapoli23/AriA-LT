//
//  AriaTurnCreditNote.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La nota sotto una risposta: "2.4 credits · Effort: High", con i tag "Extra credits" e "Lighter model". Tutto viene
//  dall'evento `aria.turn_usage` della risposta; la config decide solo due cose (nota spenta, tag "Extra credits") e
//  finché non si conosce la nota si mostra. Stesse regole di turn-credit-note.tsx della web.
//

import Foundation

nonisolated struct AriaTurnCreditNote: Equatable, Sendable {
    /// Il testo con le sue parti separate da " · ".
    let text: String
    /// Capsule accanto al testo: "Extra credits", "Lighter model".
    let tags: [String]

    /// `nil` quando non c'è niente da dire: nessun evento, nota spenta (`ui.credit_note_mode == "off"`), un fallimento
    /// gratuito, o una ripresa senza l'addebito di prima.
    static func make(usage: AriaTurnUsage?, config: AriaUsageConfig?, locale: Locale = .autoupdatingCurrent) -> AriaTurnCreditNote? {
        guard let usage, config?.showsCreditNote ?? true else { return nil }
        let free = usage.status == .notCharged
        if free, usage.actionStatus == .failed || usage.continuation { return nil }

        let stopped = free && usage.actionStatus == .cancelled
        var parts: [String] = []
        var tags: [String] = []
        if stopped {
            parts = [String(localized: "credits.note.stopped", defaultValue: "Stopped"), String(localized: "Not charged")]
        } else {
            parts.append(AriaCredits.phrase(usage.credits, locale: locale))
            if let effort = usage.effort {
                if effort.degraded {
                    let requested = effort.requested.title
                    let used = effort.effective.title
                    parts.append(String(localized: "\(requested) effort unavailable, ran at \(used)"))
                } else if effort.effective != .base {
                    let level = effort.effective.title
                    parts.append(String(localized: "Effort: \(level)"))
                }
            }
            if usage.overage, config?.customerVisibility == true { tags.append(String(localized: "Extra credits")) }
            if usage.degradedModel { tags.append(String(localized: "Lighter model")) }
        }
        return AriaTurnCreditNote(text: parts.joined(separator: " · "), tags: tags)
    }
}
