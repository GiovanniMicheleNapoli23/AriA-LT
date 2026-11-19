//
//  AdminUsageChart.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  I dati del grafico (contratto 3.6): un punto per giorno UTC del periodo, le linee e le parole. Solo punti semplici:
//  la vista li disegna con Swift Charts. I `Double` servono solo a disegnare; ogni testo è già scritto.
//

import Foundation

nonisolated struct AdminUsageChartPoint: Sendable, Equatable, Identifiable {
    nonisolated enum Kind: Sendable, Equatable {
        /// Un giorno con dati: il totale corrente (modo ciclo) o i crediti del giorno (modo "day").
        case actual
        /// Un giorno futuro fino a `projection.until`: l'ultimo totale più la media giornaliera, disegnato più chiaro.
        case projected
        /// Fuori dal periodo o dopo la proiezione: niente barra.
        case empty
    }

    /// `YYYY-MM-DD`, UTC.
    var day: String
    var kind: Kind
    /// L'altezza della barra; `nil` per un giorno vuoto.
    var value: Double?
    /// La parte fino alla linea degli inclusi (tutta la barra senza linea).
    var base: Double
    /// La parte sopra la linea degli inclusi: il colore "oltre", nella zona "Extra credits".
    var over: Double
    /// Il totale corrente dei crediti addebitati per azione (la linea "Credits per action"), solo se il ciclo è contato a dimensione.
    var charged: Double?
    /// L'ultimo giorno di `series`: oggi per il server, mai la data del telefono. Mai su un ciclo chiuso.
    var isToday: Bool
    /// L'etichetta dell'asse, solo per i giorni 1, 8, 15, 22 e 29.
    var axisLabel: String?

    var id: String { day }
}

nonisolated struct AdminUsageChart: Sendable, Equatable {
    var title: String
    var description: String
    var points: [AdminUsageChartPoint]
    /// La linea degli inclusi (o dei crediti di ogni giorno) e il suo testo ("Included · 5,250", "Pool · …",
    /// "Included each day · 175").
    var included: Double?
    var includedLabel: String?
    /// La linea dell'avviso (soglia più bassa sotto il 100% × inclusi), solo in modo ciclo e quando c'è già un consumo.
    var notice: Double?
    var noticeLabel: String?
    var bySize: Bool
    var showsProjection: Bool
    /// Niente consumato: il testo "No credits used yet this cycle." al posto delle barre e della legenda.
    var isEmpty: Bool
    var emptyText: String
    var accessibilityLabel: String
    // Legenda
    var usedLegend: String
    /// "Credits per action", solo quando il ciclo è contato a dimensione.
    var perActionLegend: String?
    /// "Extra", quando c'è una linea degli inclusi.
    var extraLegend: String?
    /// "Extra credits": il nome della zona sopra la linea.
    var extraZone: String
    var projectionLegend: String?
}
