//
//  AriaWorkOrdersViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  Le sezioni della schermata Task (Today, Upcoming, Past per giorno) calcolate una volta per cambiamento, non a
//  ogni disegno della vista: prima ogni proprietà rifiltrava tutti gli ordini con la ricerca e il corpo le
//  leggeva una dozzina di volte. Si ricalcolano quando cambia la lista dello store (`listRevision`), quando la
//  ricerca si ferma (dopo una breve pausa, subito se il campo si svuota) e a ogni ritorno sulla schermata
//  (il giorno può essere cambiato).
//

import Foundation
import Observation

@MainActor
@Observable
final class AriaWorkOrdersViewModel {
    /// I chiusi di un giorno (conta l'ultimo aggiornamento, cioè la chiusura).
    struct PastDay: Identifiable {
        let day: Date
        let orders: [AriaWorkOrder]
        var id: Date { day }
    }

    struct Sections {
        /// Da fare oggi: scadenza oggi, già scaduti e senza data (l'ordine è quello del server).
        var today: [AriaWorkOrder] = []
        /// Aperti con scadenza futura.
        var upcoming: [AriaWorkOrder] = []
        /// Chiusi per giorno, dal più recente.
        var pastByDay: [PastDay] = []
        var closedCount = 0

        var isEmpty: Bool { today.isEmpty && upcoming.isEmpty && closedCount == 0 }
    }

    let store: AriaWorkOrderStore

    /// Il testo del campo di ricerca: le sezioni seguono `appliedText`, dopo una breve pausa.
    var searchText = "" {
        didSet { searchTextChanged() }
    }
    /// La ricerca applicata (com'è scritta nel campo: gli spazi ai bordi si tolgono solo per confrontare).
    private(set) var appliedText = ""
    private(set) var sections = Sections()
    @ObservationIgnored private let searchDebouncer = AriaDebouncer()

    init(store: AriaWorkOrderStore) {
        self.store = store
        rebuildSections()
    }

    /// C'è una ricerca e non trova niente, né tra gli aperti né tra i chiusi.
    var hasNoSearchResults: Bool { !appliedText.isEmpty && sections.isEmpty }

    // MARK: Ricalcolo

    /// La lista dello store è cambiata, o si torna sulla schermata.
    func rebuildSections() {
        let query = appliedText.trimmingCharacters(in: .whitespaces)
        let open = query.isEmpty ? store.orders : store.orders.filter { Self.matches($0, query) }
        let closed = query.isEmpty ? store.closedOrders : store.closedOrders.filter { Self.matches($0, query) }
        let calendar = Calendar.current
        let endOfToday = calendar.startOfDay(for: .now).addingTimeInterval(24 * 3600)

        var next = Sections()
        for order in open {
            if (order.dueDate ?? .distantPast) < endOfToday { next.today.append(order) } else { next.upcoming.append(order) }
        }
        let grouped = Dictionary(grouping: closed) {
            calendar.startOfDay(for: $0.updatedAt ?? $0.dueDate ?? $0.createdAt ?? .distantPast)
        }
        next.pastByDay = grouped.sorted { $0.key > $1.key }.map { PastDay(day: $0.key, orders: $0.value) }
        next.closedCount = closed.count
        sections = next
    }

    private static func matches(_ order: AriaWorkOrder, _ query: String) -> Bool {
        [order.title, order.assetTag, order.zone, order.category].contains {
            $0?.localizedStandardContains(query) == true
        }
    }

    // MARK: Ricerca

    private func searchTextChanged() {
        guard searchText != appliedText else {
            searchDebouncer.cancel()
            return
        }
        if searchText.isEmpty {
            searchDebouncer.flush { applySearch() }
        } else {
            searchDebouncer.schedule { [weak self] in self?.applySearch() }
        }
    }

    private func applySearch() {
        appliedText = searchText
        rebuildSections()
    }
}
