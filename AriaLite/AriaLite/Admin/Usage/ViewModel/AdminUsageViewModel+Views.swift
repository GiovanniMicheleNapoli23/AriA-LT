//
//  AdminUsageViewModel+Views.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Piccole derivazioni per le viste della pagina Usage: testi delle schede che aspettano o falliscono, la riga dei fatti,
//  cosa fa un'azione dell'avviso e gli indici del grafico. Le viste restano mute: disegnano e inoltrano.
//

import Foundation

extension AdminUsageViewModel {
    // MARK: Testi delle schede in attesa o fallite

    /// "Included credits" e la sua frase, per la scheda mentre il saldo si legge o se è fallito.
    var metersTitle: String { AdminUsageMetersBuilder.title }
    var metersDescription: String { AdminUsageMetersBuilder.description }
    var metersLoadError: String { AdminUsageMetersBuilder.loadError }

    /// "Knowledge storage": la stessa chiave della scheda pronta.
    var storageTitle: String { String(localized: "usage.storage.title", defaultValue: "Knowledge storage") }

    /// "Talk with Aria": la stessa chiave della scheda pronta.
    var liveTalkTitle: String { AdminUsageLiveTalkBuilder.title }

    // MARK: Intestazione

    /// Le date, l'azzeramento e i giorni che restano su una riga sola.
    var headingFactsLine: String? {
        guard let facts = heading?.facts, !facts.isEmpty else { return nil }
        return facts.joined(separator: " · ")
    }

    // MARK: Azioni dell'avviso

    /// Fa ciò che l'azione dice: tornare al ciclo corrente, scorrere alla scheda del tetto o aprire la mail alle vendite.
    func perform(_ action: AdminUsageAlertAction, scrollToLimit: () -> Void, open: (URL) -> Void) {
        switch action.kind {
        case .back: backToCurrentCycle()
        case .limit: scrollToLimit()
        case .plan(let url): open(url)
        }
    }
}

extension AdminUsageChart {
    /// I giorni con una barra (quelli senza dati e fuori dal periodo restano vuoti ma tengono il loro posto sull'asse).
    var drawnPoints: [AdminUsageChartPoint] { points.filter { $0.kind != .empty } }

    /// Tutti i giorni del periodo, in ordine: il dominio dell'asse x.
    var days: [String] { points.map(\.day) }

    /// I giorni che portano un'etichetta sull'asse.
    var axisDays: [String] { points.filter { $0.axisLabel != nil }.map(\.day) }

    func axisLabel(for day: String) -> String? {
        points.first { $0.day == day }?.axisLabel
    }
}
