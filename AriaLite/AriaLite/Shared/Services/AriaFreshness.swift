//
//  AriaFreshness.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  Quando rileggere i dati entrando in una sezione: subito la prima volta, poi solo se quelli mostrati hanno più
//  di `maxAge` secondi. Tirare per aggiornare, una modifica salvata o un cambio di azienda/sito rileggono sempre
//  (`invalidate()` o la lettura forzata del view model). Nei view model @Observable va tenuto `@ObservationIgnored`.
//

import Foundation

nonisolated struct AriaFreshness: Sendable {
    /// Quanto restano buoni i dati di una sezione: rientrandoci prima non si richiedono al server.
    static let sectionMaxAge: TimeInterval = 45

    let maxAge: TimeInterval
    private(set) var loadedAt: Date?

    init(maxAge: TimeInterval = AriaFreshness.sectionMaxAge) {
        self.maxAge = maxAge
    }

    /// Mai letti, o letti da più di `maxAge`.
    func isStale(now: Date = .now) -> Bool {
        guard let loadedAt else { return true }
        return now.timeIntervalSince(loadedAt) >= maxAge
    }

    /// Da chiamare dopo una lettura riuscita.
    mutating func markLoaded(at date: Date = .now) { loadedAt = date }

    /// La prossima entrata rilegge (dopo un errore, un cambio di azienda o di sito).
    mutating func invalidate() { loadedAt = nil }
}
