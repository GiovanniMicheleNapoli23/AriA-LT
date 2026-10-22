//
//  AdminSparePartDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un ricambio (pagina /spare-parts/{id} della web): scheda aggiornata dal server,
//  storico dei prezzi, nome del fornitore, foto e la correzione rapida della quantità a magazzino.
//  I tocchi su +/− si sommano e partono insieme dopo una breve pausa (un PATCH solo, non uno per tocco).
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminSparePartDetailViewModel {
    let owner: AdminSparePartsViewModel
    private var backend: AriaBackend { owner.backend }
    private var api: AdminSparePartsAPI { AdminSparePartsAPI(api: backend.api) }

    /// Riassunto dello storico prezzi.
    struct PriceSummary: Equatable {
        let latest: Double
        let lowest: Double
        let highest: Double
        let average: Double
        let count: Int
    }

    enum HistoryState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    // MARK: - State

    private(set) var part: AdminSparePart
    private(set) var isLoading = false
    private(set) var failure: AdminSparePartsFailure?
    private(set) var priceHistory: [AdminSparePartPriceEntry] = []
    private(set) var historyState = HistoryState.loading
    var showsAllHistory = false

    /// La quantità scelta con +/− o "imposta" e non ancora confermata dal server.
    private(set) var pendingStock: Int?
    private(set) var isSavingStock = false
    /// Errore della correzione di quantità (alert).
    var stockError: String?
    var isShowingStockError: Bool {
        get { stockError != nil }
        set { if !newValue { stockError = nil } }
    }
    /// "Imposta quantità" (alert con il campo).
    var isSettingQuantity = false
    var quantityInput = ""
    /// Il modulo di modifica aperto (sheet).
    var editForm: AdminSparePartFormViewModel?

    private var stockTask: Task<Void, Never>?
    /// Pausa dopo l'ultimo tocco su +/− prima di salvare.
    private static let stockDebounce = Duration.milliseconds(700)
    /// Righe di storico mostrate prima di "mostra tutto".
    static let historyPreviewCount = 5

    init(part: AdminSparePart, owner: AdminSparePartsViewModel) {
        self.part = part
        self.owner = owner
    }

    // MARK: - Caricamento

    func load() async {
        isLoading = true
        defer { isLoading = false }
        async let history: Void = loadHistory()
        async let vendors: Void = owner.vendors.loadIfNeeded()
        do {
            let fresh = try await api.part(id: part.id)
            part = fresh
            owner.didSave(fresh)
            failure = nil
        } catch {
            if let failure = AdminSparePartsFailure.from(error, action: .read, backend: backend) { self.failure = failure }
        }
        _ = await (history, vendors)
    }

    private func loadHistory() async {
        if priceHistory.isEmpty { historyState = .loading }
        do {
            priceHistory = try await api.priceHistory(id: part.id)
            historyState = .loaded
        } catch {
            if let failure = AdminSparePartsFailure.from(error, action: .read, backend: backend) {
                historyState = .failed(failure.message)
            }
        }
    }

    func retryHistory() async { await loadHistory() }

    // MARK: - Scheda

    var vendorName: String? {
        guard let id = part.vendorId else { return nil }
        // Fornitore non (ancora) nell'elenco: meglio l'id che niente.
        return owner.vendors.name(for: id) ?? (owner.vendors.hasLoaded ? id : nil)
    }

    /// La foto, solo se https; un percorso relativo si risolve sull'host dell'API.
    var photoURL: URL? {
        guard let raw = part.photoUrl, let url = URL(string: raw, relativeTo: backend.api.config.apiBaseURL) else {
            return nil
        }
        return AriaURLPolicy.image(url.absoluteURL)
    }

    var details: [(label: String, value: String)] {
        let rows: [(String, String?)] = [
            (String(localized: "Category"), part.category?.localized),
            (String(localized: "Manufacturer"), part.manufacturer),
            (String(localized: "Part number"), part.partNumber),
            (String(localized: "Unit price"), part.unitPrice.map(Self.formatPrice)),
            (String(localized: "Unit"), part.unit),
            (String(localized: "Location"), part.location),
            (String(localized: "Barcode"), part.barcode),
            (String(localized: "Vendor"), vendorName),
            (String(localized: "Stock tracking"), part.nonStock ? String(localized: "Non-stock item") : String(localized: "Tracked")),
            (String(localized: "Created"), part.createdAt.map(Self.formatDate)),
            (String(localized: "Updated"), part.updatedAt.map(Self.formatDate)),
        ]
        return rows.compactMap { label, value in
            guard let value, !value.isEmpty else { return nil }
            return (label, value)
        }
    }

    // MARK: - Storico prezzi

    var visibleHistory: [AdminSparePartPriceEntry] {
        showsAllHistory ? priceHistory : Array(priceHistory.prefix(Self.historyPreviewCount))
    }

    var hiddenHistoryCount: Int { max(0, priceHistory.count - Self.historyPreviewCount) }

    var priceSummary: PriceSummary? {
        let costs = priceHistory.compactMap(\.unitCost)
        guard let latest = costs.first, let lowest = costs.min(), let highest = costs.max() else { return nil }
        return PriceSummary(latest: latest, lowest: lowest, highest: highest,
                            average: costs.reduce(0, +) / Double(costs.count), count: costs.count)
    }

    func toggleHistory() { showsAllHistory.toggle() }

    // MARK: - Quantità a magazzino

    var displayedStock: Int { pendingStock ?? part.stockQuantity }
    var canDecrement: Bool { displayedStock > 0 }
    /// Un articolo non a magazzino non ha una quantità da correggere.
    var canAdjustStock: Bool { !part.nonStock }
    var isStockPending: Bool { pendingStock != nil || isSavingStock }

    /// Sotto scorta con la quantità mostrata (anche prima che il server confermi).
    var isDisplayedStockLow: Bool {
        guard !part.nonStock else { return false }
        return displayedStock <= 0 || part.minQuantity.map { displayedStock <= $0 } == true
    }

    /// Sotto il numero: unità e scorta minima ("pcs · min 10").
    var stockCaption: String? {
        let parts = [part.unit, part.minQuantity.map { String(localized: "min \($0)") }].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    func increment() { adjust(by: 1) }
    func decrement() { adjust(by: -1) }

    private func adjust(by delta: Int) {
        let target = max(0, displayedStock + delta)
        guard target != displayedStock else { return }
        pendingStock = target
        scheduleStockSave(after: Self.stockDebounce)
    }

    func beginSettingQuantity() {
        quantityInput = "\(displayedStock)"
        isSettingQuantity = true
    }

    /// Salva la quantità scritta; un valore non valido non si manda e lo si dice.
    func commitQuantity() {
        guard let value = Int(quantityInput.trimmingCharacters(in: .whitespaces)), value >= 0 else {
            stockError = String(localized: "Enter a whole number, 0 or more.")
            return
        }
        guard value != displayedStock else { return }
        pendingStock = value
        scheduleStockSave(after: .zero)
    }

    /// Un tocco nuovo annulla l'attesa (e la chiamata in corso): parte solo l'ultimo valore.
    /// Il task tiene vivo il view model: chiudere il dettaglio non perde la correzione.
    private func scheduleStockSave(after delay: Duration) {
        stockTask?.cancel()
        stockTask = Task {
            if delay > .zero { try? await Task.sleep(for: delay) }
            guard !Task.isCancelled else { return }
            await self.saveStock()
        }
    }

    private func saveStock() async {
        guard let target = pendingStock else { return }
        guard target != part.stockQuantity else {
            pendingStock = nil
            return
        }
        isSavingStock = true
        defer { isSavingStock = false }
        do {
            let saved = try await api.update(id: part.id, .stock(target))
            part = saved
            owner.didSave(saved)
            if pendingStock == target { pendingStock = nil }
        } catch {
            // Annullata da un tocco nuovo: ci pensa il salvataggio successivo.
            guard let failure = AdminSparePartsFailure.from(error, action: .write, backend: backend) else { return }
            if pendingStock == target { pendingStock = nil }
            stockError = failure.message
        }
    }

    // MARK: - Modifica

    func startEditing() {
        editForm = AdminSparePartFormViewModel(mode: .edit(part), owner: owner) { [weak self] saved in
            self?.part = saved
        }
    }

    // MARK: - Formati

    nonisolated static func formatPrice(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }

    nonisolated static func formatQuantity(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    nonisolated static func formatDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}
