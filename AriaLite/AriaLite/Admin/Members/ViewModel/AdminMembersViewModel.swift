//
//  AdminMembersViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Members, come la pagina /members della web. Vive in AppViewModel: i dati restano fra un
//  cambio di sezione e l'altro. L'elenco è dell'azienda attiva (GET /v1/members); ricerca e filtri
//  (ruolo, stato, team) agiscono sul telefono, senza richiamare il server, così le voci dei filtri restano
//  quelle di tutto l'elenco.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminMembersViewModel {
    let backend: AriaBackend

    /// Cosa mostrare al posto della lista.
    enum Placeholder: Equatable {
        case loading
        case failed(AdminMembersFailure)
        case empty
        case noResults(String)
        case noMatches
    }

    // MARK: - State

    private(set) var members: [AdminMember] = []
    /// L'azienda per cui l'elenco è stato scaricato.
    private var loadedCompanyId: String?
    private(set) var isLoading = false
    private(set) var failure: AdminMembersFailure?
    private(set) var lastUpdated: Date?

    var query = ""
    /// La chiave del ruolo scelto (vedi `AdminMemberRole.key`).
    var roleFilter: String?
    var statusFilter: AdminMemberStatusFilter?
    var teamFilter: String?

    /// I team fra cui scegliere per un turno (caricati la prima volta che servono).
    var teams: [AdminMemberTeamOption] = []
    var teamsCompanyId: String?
    var isLoadingTeams = false
    var teamsFailure: AdminMembersFailure?

    /// I moduli aperti (sheet).
    var newMemberForm: AdminMemberCreateViewModel?
    var adHocTeamForm: AdminMemberAdHocTeamViewModel?

    init(backend: AriaBackend) {
        self.backend = backend
    }

    /// All'uscita dall'account: non resta niente dell'azienda precedente.
    func reset() {
        members = []
        loadedCompanyId = nil
        isLoading = false
        failure = nil
        lastUpdated = nil
        query = ""
        roleFilter = nil
        statusFilter = nil
        teamFilter = nil
        teams = []
        teamsCompanyId = nil
        isLoadingTeams = false
        teamsFailure = nil
        newMemberForm = nil
        adHocTeamForm = nil
    }

    // MARK: - Caricamento

    /// Cambia quando va riscaricato l'elenco: l'azienda.
    var loadKey: String { backend.activeCompanyId ?? "-" }

    var hasLoaded: Bool { loadedCompanyId == backend.activeCompanyId && lastUpdated != nil }

    func loadIfNeeded() async {
        if !hasLoaded { await refresh() }
    }

    func refresh() async {
        let company = backend.activeCompanyId
        isLoading = true
        defer { isLoading = false }
        do {
            let fresh = try await AdminMembersAPI(api: backend.api).list()
            // Nel frattempo è cambiata l'azienda: questo elenco non è più quello giusto.
            guard company == backend.activeCompanyId else { return }
            members = fresh
            loadedCompanyId = company
            failure = nil
            lastUpdated = .now
            dropStaleFilters()
        } catch {
            if let failure = AdminMembersFailure.from(error, action: .read, backend: backend) { self.failure = failure }
        }
    }

    /// Un membro riletto (dal dettaglio): si aggiorna dov'è.
    func didRefresh(_ member: AdminMember) {
        if let index = members.firstIndex(where: { $0.id == member.id }) { members[index] = member }
    }

    // MARK: - Filtri

    var visibleMembers: [AdminMember] {
        members.filter(matches).sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    private func matches(_ member: AdminMember) -> Bool {
        if let roleFilter, member.role.map(AdminMemberRole.key) != roleFilter { return false }
        if let statusFilter, !statusFilter.matches(member) { return false }
        if let teamFilter, !member.teamIds.contains(teamFilter) { return false }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }
        return [member.fullName, member.email].contains { $0?.localizedStandardContains(q) == true }
    }

    var roleOptions: [AdminMemberFilterOption] {
        var found: [String: (label: String, count: Int)] = [:]
        for member in members {
            guard let role = member.role else { continue }
            let key = AdminMemberRole.key(role)
            found[key] = (found[key]?.label ?? AdminMemberRole.label(role), (found[key]?.count ?? 0) + 1)
        }
        return found.map { AdminMemberFilterOption(key: $0.key, label: $0.value.label, count: $0.value.count) }
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }

    var statusOptions: [AdminMemberFilterOption] {
        AdminMemberStatusFilter.allCases.map { status in
            let count = members.filter(status.matches).count
            return AdminMemberFilterOption(key: status.rawValue, label: status.localized, count: count)
        }
    }

    /// I team in cui compare almeno un membro, quello di oggi o di appartenenza.
    var teamFilterOptions: [AdminMemberFilterOption] {
        var found: [String: (label: String, count: Int)] = [:]
        for member in members {
            var seen = Set<String>()
            for (id, name) in teamNames(of: member) where seen.insert(id).inserted {
                found[id] = (found[id]?.label ?? name, (found[id]?.count ?? 0) + 1)
            }
        }
        return found.map { AdminMemberFilterOption(key: $0.key, label: $0.value.label, count: $0.value.count) }
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }

    private func teamNames(of member: AdminMember) -> [(String, String)] {
        var pairs = member.homeTeams.map { ($0.teamId, $0.teamName) }
        if let team = member.currentTeam { pairs.append((team.id, team.name)) }
        return pairs.filter { !$0.1.isEmpty }
    }

    var hasActiveFilters: Bool { roleFilter != nil || statusFilter != nil || teamFilter != nil }

    func selectRole(_ key: String?) { roleFilter = key }

    func selectStatus(_ key: String?) { statusFilter = key.flatMap(AdminMemberStatusFilter.init(rawValue:)) }

    func selectTeam(_ key: String?) { teamFilter = key }

    func clearFilters() {
        roleFilter = nil
        statusFilter = nil
        teamFilter = nil
    }

    /// Dopo un aggiornamento un filtro può puntare a qualcosa che non c'è più: si toglie.
    private func dropStaleFilters() {
        if let roleFilter, !roleOptions.contains(where: { $0.key == roleFilter }) { self.roleFilter = nil }
        if let teamFilter, !teamFilterOptions.contains(where: { $0.key == teamFilter }) { self.teamFilter = nil }
    }

    var placeholder: Placeholder? {
        if !hasLoaded {
            if let failure { return .failed(failure) }
            return .loading
        }
        if members.isEmpty { return .empty }
        guard visibleMembers.isEmpty else { return nil }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return q.isEmpty ? .noMatches : .noResults(q)
    }

    /// Lista già a schermo ma l'ultimo aggiornamento è fallito.
    var refreshFailed: Bool { hasLoaded && failure != nil }

    /// I ruoli già in uso come li ha scritti il server, per suggerirli nel modulo del nuovo membro.
    var roleSuggestions: [String] {
        var seen = Set<String>()
        let used = members.compactMap(\.role)
        return (used + AdminMemberRole.suggestions).filter { seen.insert(AdminMemberRole.key($0)).inserted }
    }
}
