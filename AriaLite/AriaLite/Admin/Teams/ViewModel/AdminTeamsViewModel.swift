//
//  AdminTeamsViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Teams, come la pagina /teams della web. Vive in AppViewModel: i dati restano fra un cambio di
//  sezione e l'altro. L'elenco è di tutta l'azienda (GET /v1/teams); stabilimento e ricerca filtrano sul telefono.
//  Il carico di ogni squadra si scarica a parte, in parallelo, per la barra di ogni riga.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminTeamsViewModel {
    let backend: AriaBackend

    /// Cosa mostrare al posto della lista.
    enum Placeholder: Equatable {
        case loading
        case failed(AdminTeamsFailure)
        case empty
        case noResults(String)
        case noMatches
    }

    // MARK: - State

    private(set) var teams: [AdminTeam] = []
    /// Il carico per id di squadra (manca finché non arriva, o se la chiamata fallisce).
    private(set) var workloads: [String: AdminTeamWorkload] = [:]
    /// Le persone dell'azienda: danno il nome ai membri e le scelte di chi aggiungere.
    private(set) var people: [AdminTeamPerson] = []
    private var loadedCompanyId: String?
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var failure: AdminTeamsFailure?
    private(set) var lastUpdated: Date?

    var query = ""
    /// Lo stabilimento scelto come filtro (`nil` = tutti).
    var plantFilter: String?
    /// Il modulo di creazione aperto (sheet).
    var newTeamForm: AdminTeamFormViewModel?

    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var peopleLoaded = false

    init(backend: AriaBackend) {
        self.backend = backend
    }

    /// All'uscita dall'account: non resta niente dell'azienda precedente.
    func reset() {
        generation += 1
        teams = []
        workloads = [:]
        people = []
        loadedCompanyId = nil
        hasLoaded = false
        isLoading = false
        failure = nil
        lastUpdated = nil
        query = ""
        plantFilter = nil
        newTeamForm = nil
        peopleLoaded = false
    }

    var api: AdminTeamsAPI { AdminTeamsAPI(api: backend.api) }

    // MARK: - Caricamento

    /// Cambia quando va riscaricato l'elenco: l'azienda.
    var loadKey: String { backend.activeCompanyId ?? "-" }

    func loadIfNeeded() async {
        if !hasLoaded || loadedCompanyId != backend.activeCompanyId { await refresh() }
    }

    func refresh() async {
        generation += 1
        let current = generation
        let companyId = backend.activeCompanyId
        isLoading = true
        defer { if current == generation { isLoading = false } }
        do {
            let fresh = try await api.list()
            guard current == generation else { return }
            teams = fresh
            loadedCompanyId = companyId
            hasLoaded = true
            failure = nil
            lastUpdated = .now
            // Il filtro punta a uno stabilimento che non ha più squadre: si toglie.
            if let plantFilter, !fresh.contains(where: { $0.plantId == plantFilter }) { self.plantFilter = nil }
            await refreshWorkloads(for: fresh.map(\.id), generation: current)
        } catch {
            guard current == generation else { return }
            if let failure = AdminTeamsFailure.from(error, action: .read, backend: backend) { self.failure = failure }
        }
    }

    /// Riscarica il carico di alcune squadre (dopo una modifica nel dettaglio o sulla bacheca).
    func refreshWorkloads(for ids: [String]) async {
        await refreshWorkloads(for: ids, generation: generation)
    }

    private func refreshWorkloads(for ids: [String], generation current: Int) async {
        let fresh = await api.workloads(teamIds: ids)
        guard current == generation else { return }
        workloads.merge(fresh) { _, new in new }
    }

    /// Le persone dell'azienda, una volta sola (o di nuovo se la prima volta è fallita).
    func loadPeople() async {
        guard !peopleLoaded else { return }
        if let rows = try? await api.people() {
            people = rows
            peopleLoaded = true
        }
    }

    func person(id: String?) -> AdminTeamPerson? {
        guard let id else { return nil }
        return people.first { $0.id == id }
    }

    // MARK: - Stabilimenti e filtri

    func plantName(for id: String?) -> String? {
        guard let id else { return nil }
        return backend.plants.first { $0.id == id }?.name
    }

    /// Gli stabilimenti che hanno almeno una squadra, più quello scelto.
    var plantOptions: [AriaPlant] {
        let used = Set(teams.compactMap(\.plantId)).union(plantFilter.map { [$0] } ?? [])
        return backend.plants.filter { used.contains($0.id) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Un solo stabilimento non è un filtro.
    var showsPlantFilter: Bool { plantOptions.count > 1 || plantFilter != nil }

    var plantFilterTitle: String {
        plantFilter.flatMap(plantName(for:)) ?? String(localized: "All plants")
    }

    var visibleTeams: [AdminTeam] {
        teams.filter(matches).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private func matches(_ team: AdminTeam) -> Bool {
        if let plantFilter, team.plantId != plantFilter { return false }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }
        return [team.name, team.description, plantName(for: team.plantId)].contains {
            $0?.localizedStandardContains(q) == true
        }
    }

    var hasActiveFilters: Bool { plantFilter != nil }

    func clearFilters() { plantFilter = nil }

    var placeholder: Placeholder? {
        if !hasLoaded {
            if let failure { return .failed(failure) }
            return .loading
        }
        if teams.isEmpty { return .empty }
        guard visibleTeams.isEmpty else { return nil }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return q.isEmpty ? .noMatches : .noResults(q)
    }

    /// Lista già a schermo ma l'ultimo aggiornamento è fallito.
    var refreshFailed: Bool { hasLoaded && failure != nil }

    // MARK: - Modifiche

    func startCreating() {
        newTeamForm = AdminTeamFormViewModel(mode: .create, owner: self)
    }

    func didCreate(_ team: AdminTeam) {
        teams.removeAll { $0.id == team.id }
        teams.append(team)
    }

    /// Una squadra modificata o riletta: si aggiorna dov'è.
    func didSave(_ team: AdminTeam) {
        if let index = teams.firstIndex(where: { $0.id == team.id }) { teams[index] = team }
    }

    func didDelete(id: String) {
        teams.removeAll { $0.id == id }
        workloads[id] = nil
        if let plantFilter, !teams.contains(where: { $0.plantId == plantFilter }) { self.plantFilter = nil }
    }

    func didLoad(workload: AdminTeamWorkload, for id: String) {
        workloads[id] = workload
    }
}
