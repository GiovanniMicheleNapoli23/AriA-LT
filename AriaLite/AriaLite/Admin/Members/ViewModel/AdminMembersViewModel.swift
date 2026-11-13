//
//  AdminMembersViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Members, come la pagina /members della web. Vive in AppViewModel: i dati restano fra un
//  cambio di sezione e l'altro. L'elenco è dell'azienda attiva (GET /v1/members, anche sospesi e chi non lavora
//  sul campo); ricerca e filtri (ruolo, stato, team) agiscono sul telefono, senza richiamare il server, così le
//  voci dei filtri restano quelle di tutto l'elenco. Solo per owner e admin si legge in parallelo anche
//  GET …/mobile-users: licenze e riga mobile di ogni persona (la scheda e il badge la usano).
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

    /// Le righe mobile per id della persona (solo per owner e admin); vuote se la chiamata non c'è o è fallita.
    private(set) var mobileRows: [String: AdminMobileUser] = [:]
    /// Le licenze dell'app (solo per owner e admin).
    private(set) var seats: AdminMobileUserSeats?

    /// Le schede aperte sopra l'elenco (`NavigationStack(path:)`).
    var path: [AdminMemberRoute] = []
    /// Gli avvisi dell'ultima creazione, per id della persona: la scheda li prende una volta sola.
    @ObservationIgnored var creationNotices: [String: [AdminMemberCreationNotice]] = [:]

    var query = ""
    /// L'id del ruolo scelto, o una delle chiavi di `AdminMemberRoleFilter`.
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
        mobileRows = [:]
        seats = nil
        path = []
        creationNotices = [:]
        query = ""
        roleFilter = nil
        statusFilter = nil
        teamFilter = nil
        teams = []
        teamsCompanyId = nil
        isLoadingTeams = false
        teamsFailure = nil
        newMemberForm = nil
    }

    // MARK: - Caricamento

    /// Cambia quando va riscaricato l'elenco: l'azienda.
    var loadKey: String { backend.activeCompanyId ?? "-" }

    var hasLoaded: Bool { loadedCompanyId == backend.activeCompanyId && lastUpdated != nil }

    func loadIfNeeded() async {
        if !hasLoaded { await refresh() }
    }

    /// Rilegge l'elenco e, per owner e admin, in parallelo le licenze e le righe mobile. Se la lista mobile
    /// fallisce l'elenco resta e licenze e dettagli mobili spariscono (il badge viene da `access`).
    func refresh() async {
        let company = backend.activeCompanyId
        let mobileCompany = viewer.isAdmin ? company : nil
        let api = backend.api
        isLoading = true
        defer { isLoading = false }
        async let mobile = Self.fetchMobile(api: api, companyId: mobileCompany)
        do {
            let fresh = try await AdminMembersAPI(api: api).list()
            let response = await mobile
            // Nel frattempo è cambiata l'azienda: questo elenco non è più quello giusto.
            guard company == backend.activeCompanyId else { return }
            members = fresh
            var rows: [String: AdminMobileUser] = [:]
            for row in response?.operators ?? [] { rows[row.id] = row }
            mobileRows = rows
            seats = response?.seats
            loadedCompanyId = company
            failure = nil
            lastUpdated = .now
            dropStaleFilters()
        } catch {
            // Il lavoro mobile in corso si annulla da solo uscendo da qui.
            if let failure = AdminMembersFailure.from(error, action: .read, backend: backend) { self.failure = failure }
        }
    }

    /// GET …/mobile-users; `nil` se non si chiede (non è admin) o se fallisce: non è un errore dell'elenco.
    private nonisolated static func fetchMobile(api: AriaAPIClient, companyId: String?) async -> AdminMobileUsersResponse? {
        guard let companyId else { return nil }
        return try? await api.call(AdminMobileUsersAPI.list(companyId: companyId))
    }

    /// Un membro riletto (dal dettaglio): si aggiorna dov'è.
    func didRefresh(_ member: AdminMember) {
        if let index = members.firstIndex(where: { $0.id == member.id }) { members[index] = member }
    }

    // MARK: - Chi guarda e cosa vede

    /// Chi guarda, ricavato ogni volta dal backend: i diritti possono cambiare mentre la sezione è aperta.
    var viewer: AdminPeopleViewer { AdminPeopleViewer(backend: backend) }

    var canCreate: Bool { AdminMemberRules.canCreate(viewer) }

    func mobileRow(for id: String) -> AdminMobileUser? { mobileRows[id] }

    /// I titolari attivi in azienda: l'ultimo non si sospende né si rimuove.
    var activeOwners: Int { members.filter { $0.isOwner && !$0.isSuspendedInCompany }.count }

    func badge(for member: AdminMember) -> AdminMemberBadgeKind? {
        AdminMemberRules.badge(member, row: mobileRow(for: member.id))
    }

    func roleLine(for member: AdminMember) -> String? {
        let viewer = viewer
        return AdminMemberRules.roleLine(member, viewerCanManageRoles: viewer.isAdmin || viewer.canManageRoles)
    }

    /// "App seats: 7 of 10", solo per owner e admin quando le licenze sono arrivate.
    var seatsText: String? {
        guard let seats else { return nil }
        return String(localized: "App seats: \(seats.used) of \(seats.total)")
    }

    var seatsAreFull: Bool { seats?.isFull ?? false }

    // MARK: - Filtri

    var visibleMembers: [AdminMember] {
        members.filter(matches).sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    private func matches(_ member: AdminMember) -> Bool {
        if let roleFilter, !AdminMemberRoleFilter.matches(roleFilter, member) { return false }
        if let statusFilter, !statusFilter.matches(member) { return false }
        if let teamFilter, !member.teamIds.contains(teamFilter) { return false }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }
        return [member.fullName, member.email].contains { $0?.localizedStandardContains(q) == true }
    }

    /// Per ruolo di Roles & Rights (`access_role.id`), più "Owners and admins" e "No role" quando servono.
    var roleOptions: [AdminMemberFilterOption] {
        var found: [String: (label: String, count: Int)] = [:]
        for member in members {
            guard let role = member.accessRole else { continue }
            found[role.id] = (found[role.id]?.label ?? role.name, (found[role.id]?.count ?? 0) + 1)
        }
        let roles = found.map { AdminMemberFilterOption(key: $0.key, label: $0.value.label, count: $0.value.count) }
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
        let special = [
            AdminMemberFilterOption(key: AdminMemberRoleFilter.ownersAndAdmins, label: String(localized: "Owners and admins"),
                                    count: members.filter(\.isOwnerOrAdmin).count),
            AdminMemberFilterOption(key: AdminMemberRoleFilter.noRole, label: String(localized: "No role"),
                                    count: members.filter { AdminMemberRoleFilter.matches(AdminMemberRoleFilter.noRole, $0) }.count)
        ].filter { $0.count > 0 }
        return special + roles
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
}
