//
//  AdminScenarioClosuresViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda Closures: le procedure chiuse senza una riparazione confermata, dalle più recenti. Lo stato
//  si chiede al server (senza, tutti); stabilimento e ricerca filtrano qui. "Show more" alza il limite fino a 200.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminScenarioClosuresViewModel {
    let backend: AriaBackend

    private(set) var closures: [AdminScenarioClosure] = []
    /// Gli avvisi aperti, qualunque sia il filtro.
    private(set) var unreadCount: Int?
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    private(set) var lastUpdated: Date?
    private(set) var limit = AdminScenarioClosuresViewModel.pageSize
    @ObservationIgnored private var loadedScope: String?

    var searchText = ""
    var statusFilter: AdminScenarioClosureStatus?

    static let pageSize = 50
    static let maxLimit = 200

    init(backend: AriaBackend) {
        self.backend = backend
    }

    private var scope: String { "\(backend.activeCompanyId ?? "-")|\(statusFilter?.rawValue ?? "all")" }
    var loadKey: String { "\(scope)|\(limit)" }

    // MARK: Lista

    var visibleClosures: [AdminScenarioClosure] {
        let plant = backend.activePlantId
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return closures
            .filter { plant == nil || $0.plantId == nil || $0.plantId == plant }
            .filter { query.isEmpty || $0.searchableFields.contains { $0.localizedStandardContains(query) } }
    }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var statusFilterLabel: String { statusFilter?.label ?? String(localized: "All") }
    var canShowMore: Bool { hasLoaded && closures.count >= limit && limit < Self.maxLimit }

    func showMore() {
        limit = min(limit + Self.pageSize, Self.maxLimit)
    }

    var subtitle: String {
        let count = visibleClosures.count
        return String(localized: "\(count) closures")
    }

    /// "3 open alerts", solo se ce ne sono.
    var unreadNotice: String? {
        guard let count = unreadCount, count > 0 else { return nil }
        return String(localized: "\(count) open alerts to decide on")
    }

    func closure(id: String) -> AdminScenarioClosure? {
        closures.first { $0.id == id }
    }

    // MARK: Caricamento

    func load() async {
        let scope = scope
        if scope != loadedScope {
            // Altro stato o altra azienda: si riparte dalla prima pagina.
            if loadedScope != nil { limit = Self.pageSize }
            closures = []
            hasLoaded = false
            errorMessage = nil
            loadedScope = scope
        }
        guard let companyId = backend.activeCompanyId else {
            errorMessage = AriaError.missingCompany.localizedDescription
            return
        }
        let key = loadKey
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await backend.api.call(AdminScenarioAnalysisAPI.closures(
                companyId: companyId, status: statusFilter?.rawValue, limit: limit))
            guard key == loadKey, !Task.isCancelled else { return }
            closures = response.closures
            unreadCount = response.unreadCount
            hasLoaded = true
            errorMessage = nil
            lastUpdated = .now
        } catch {
            guard key == loadKey, let message = AdminScenarioFailure.message(for: error, backend: backend) else { return }
            errorMessage = message
        }
    }

    func makeDetailViewModel(for closure: AdminScenarioClosure) -> AdminScenarioClosureDetailViewModel {
        AdminScenarioClosureDetailViewModel(backend: backend, closure: closure)
    }

    func reset() {
        closures = []
        unreadCount = nil
        isLoading = false
        hasLoaded = false
        errorMessage = nil
        lastUpdated = nil
        limit = Self.pageSize
        loadedScope = nil
        searchText = ""
        statusFilter = nil
    }
}
