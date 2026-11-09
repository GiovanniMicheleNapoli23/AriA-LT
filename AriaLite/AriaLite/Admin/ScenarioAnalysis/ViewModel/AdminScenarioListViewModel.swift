//
//  AdminScenarioListViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda Scenarios: gli scenari ricorrenti dello stabilimento attivo, con le cifre d'insieme.
//  Tipo (allarme/procedura) e stabilimento si chiedono al server; ricerca e ordinamento filtrano qui.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminScenarioListViewModel {
    let backend: AriaBackend

    private(set) var scenarios: [AdminScenario] = []
    private(set) var totalScenarios: Int?
    private(set) var totalSessions: Int?
    private(set) var overallReliability: Double?
    private(set) var provenCount: Int?
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    private(set) var lastUpdated: Date?
    @ObservationIgnored private var loadedKey: String?

    var searchText = ""
    var kindFilter: AdminScenarioKind?
    var sort: AdminScenarioSort = .mostSessions

    init(backend: AriaBackend) {
        self.backend = backend
    }

    /// Cambia quando va richiesta la lista: azienda, stabilimento o tipo.
    var loadKey: String {
        "\(backend.activeCompanyId ?? "-")|\(backend.activePlantId ?? "-")|\(kindFilter?.rawValue ?? "all")"
    }

    // MARK: Lista

    var visibleScenarios: [AdminScenario] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = scenarios.filter { query.isEmpty || $0.searchableFields.contains { $0.localizedStandardContains(query) } }
        switch sort {
        case .mostSessions:
            return filtered
        case .leastReliable:
            // Senza base per un tasso vanno in fondo.
            return filtered.sorted { ($0.metrics?.reliability ?? .infinity) < ($1.metrics?.reliability ?? .infinity) }
        case .recentlyUpdated:
            return filtered.sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
        }
    }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var kindFilterLabel: String { kindFilter?.label ?? String(localized: "All") }

    func scenario(id: String) -> AdminScenario? {
        scenarios.first { $0.id == id }
    }

    /// Le tessere in cima: quanti scenari, su quante sessioni, quanto si risolve, quanti sono provati.
    var overview: [AdminScenarioStat] {
        [
            AdminScenarioStat(title: String(localized: "Scenarios"), value: AdminScenarioFormat.count(totalScenarios ?? scenarios.count),
                              systemImage: "point.3.connected.trianglepath.dotted"),
            AdminScenarioStat(title: String(localized: "Sessions"), value: AdminScenarioFormat.count(totalSessions),
                              systemImage: "bubble.left.and.text.bubble.right"),
            AdminScenarioStat(title: String(localized: "Overall reliability"), value: AdminScenarioFormat.percent(overallReliability),
                              systemImage: "checkmark.seal", tone: .positive),
            AdminScenarioStat(title: String(localized: "Proven"), value: AdminScenarioFormat.count(provenCount),
                              systemImage: "star", tone: .positive),
        ]
    }

    var subtitle: String {
        let count = visibleScenarios.count
        return String(localized: "\(count) scenarios")
    }

    // MARK: Caricamento

    func load() async {
        let key = loadKey
        if key != loadedKey {
            scenarios = []
            hasLoaded = false
            errorMessage = nil
            loadedKey = key
        }
        guard let companyId = backend.activeCompanyId else {
            errorMessage = AriaError.missingCompany.localizedDescription
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await backend.api.call(AdminScenarioAnalysisAPI.scenarios(
                companyId: companyId, plantId: backend.activePlantId, kind: kindFilter?.rawValue))
            // Filtro o stabilimento cambiati durante la richiesta: questa risposta non vale più.
            guard key == loadKey, !Task.isCancelled else { return }
            scenarios = response.scenarios
            totalScenarios = response.totalScenarios
            totalSessions = response.totalSessions
            overallReliability = response.overallReliability
            provenCount = response.provenCount
            hasLoaded = true
            errorMessage = nil
            lastUpdated = .now
        } catch {
            guard key == loadKey, let message = AdminScenarioFailure.message(for: error, backend: backend) else { return }
            errorMessage = message
        }
    }

    func makeDetailViewModel(for scenario: AdminScenario) -> AdminScenarioDetailViewModel {
        AdminScenarioDetailViewModel(backend: backend, scenario: scenario)
    }

    func reset() {
        scenarios = []
        totalScenarios = nil
        totalSessions = nil
        overallReliability = nil
        provenCount = nil
        isLoading = false
        hasLoaded = false
        errorMessage = nil
        lastUpdated = nil
        loadedKey = nil
        searchText = ""
        kindFilter = nil
        sort = .mostSessions
    }
}
