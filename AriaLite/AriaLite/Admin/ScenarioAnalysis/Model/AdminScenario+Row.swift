//
//  AdminScenario+Row.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Cosa mostra la scheda di uno scenario nella lista: il codice allarme solo se il titolo non lo dice già,
//  e una riga di dettagli in testo semplice (ultimo esito, tendenza, maturità) al posto delle etichette.
//

import Foundation

nonisolated extension AdminScenario {
    /// "Alarm F120" ha già il codice nel titolo: ripeterlo sopra non serve.
    var rowCode: String? {
        guard let alarmCode, !displayTitle.localizedCaseInsensitiveContains(alarmCode) else { return nil }
        return alarmCode
    }

    /// Il tono dell'ultimo esito, per il pallino all'inizio della riga di dettagli.
    var lastVerdictTone: AdminScenarioTone { AdminScenarioLabel.verdictTone(lastVerdict) }

    /// "Last: Resolved · Stable · Emerging". La tendenza resta fuori finché non ci sono abbastanza dati.
    var rowDetails: String {
        var parts: [String] = []
        if let lastVerdict { parts.append(String(localized: "Last: \(AdminScenarioLabel.verdict(lastVerdict))")) }
        if let trend = metrics?.trend, AdminScenarioLabel.hasTrend(trend) { parts.append(AdminScenarioLabel.trend(trend)) }
        if let maturity = metrics?.maturity { parts.append(AdminScenarioLabel.maturity(maturity)) }
        return parts.joined(separator: " · ")
    }
}
