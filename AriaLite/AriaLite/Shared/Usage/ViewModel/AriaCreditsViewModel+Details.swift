//
//  AriaCreditsViewModel+Details.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  I dettagli del foglio "AI Operational Credits": le barre delle ultime ore e del ciclo (o della prova) e la frase
//  per VoiceOver del grafico. Le cifre e i testi sono già pronti in AriaAllowanceSummary (letti dal server);
//  qui si ordinano soltanto per la barra. Nessun token, nessuna cifra calcolata.
//

import Foundation
import SwiftUI

/// Una barra con titolo, valore, un eventuale segno di soglia e le due righe sotto.
struct AriaCreditsBarContent {
    let title: String
    let value: String
    /// Quanto è piena, 0...1 (oltre il 100% la barra si ferma al bordo).
    let fill: Double
    /// Dove sta la soglia d'avviso, 0...1.
    let tick: Double?
    let leading: String?
    let trailing: String?
    let note: String?
}

extension AriaCreditsViewModel {
    /// "Last 24 hours": "12.4 of 40 used".
    func windowBar(_ window: AriaAllowanceSummary.Window) -> AriaCreditsBarContent {
        AriaCreditsBarContent(title: window.title, value: window.value, fill: Self.clamp(window.fraction),
                              tick: nil, leading: nil, trailing: nil, note: window.note)
    }

    /// "This cycle" (o "Your trial", o "Today (UTC)"): "9.2 of 1,200", la soglia, "Resets 1 Dec", "1% used".
    func cycleBar(_ cycle: AriaAllowanceSummary.Cycle) -> AriaCreditsBarContent {
        AriaCreditsBarContent(title: cycle.title, value: cycle.value, fill: Self.clamp(cycle.fraction),
                              tick: cycle.tick, leading: cycle.resets, trailing: cycle.usedText, note: cycle.bySize)
    }

    /// "Today" / "This week": "12.4 of 40", la percentuale come la manda il server (anche oltre 100), "Resets 23 Nov".
    /// La barra si ferma al bordo; dalla soglia del server il contatore è ambra (lo sceglie `meterTint`).
    func meterBars() -> [(bar: AriaCreditsBarContent, isWarning: Bool)] {
        guard let summary else { return [] }
        return summary.meters.map { meter in
            let percent = meter.percent.map { String(localized: "\($0)% used") }
            let bar = AriaCreditsBarContent(title: meter.title, value: meter.value, fill: Self.clamp(meter.fraction),
                                            tick: nil, leading: meter.resets, trailing: percent, note: nil)
            return (bar, meter.isWarning)
        }
    }

    /// Ambra oltre la soglia del contatore, altrimenti il tono del saldo.
    func meterTint(isWarning: Bool, tone: AriaAllowanceSummary.Tone) -> Color {
        isWarning ? Color.liteWarning : tint(tone)
    }

    /// "Credits used per day over the last 7 days: 0, 3.2, 12.4 …" (le cifre scritte, per VoiceOver).
    func chartDescription(_ history: AriaAllowanceSummary.History) -> String {
        let spoken = history.days
            .map { $0.credits.formatted(.number.precision(.fractionLength(0...1))) }
            .joined(separator: ", ")
        return String(localized: "Credits used per day over the last 7 days: \(spoken)")
    }

    private static func clamp(_ value: Double) -> Double { min(1, max(0, value)) }
}
