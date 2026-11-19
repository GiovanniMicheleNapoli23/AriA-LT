//
//  AdminUserShiftsViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Oggi, Pianificazione e Cronologia di una persona (§4.1-§4.3): i team per i selettori (GET /v1/lookups/teams), lo
//  spostamento di oggi, il modulo di pianificazione, la cronologia e la rimozione di un turno. Le rotte sono quelle
//  vecchie dei membri (header `Company-Id`, snake_case). "Oggi" è il giorno UTC, come sulla web. Il resto è nei file +Today,
//  +Schedule e +History.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminUserShiftsViewModel {
    enum TeamsState: Equatable {
        case idle
        case loading
        case loaded
        /// Il testo di `AdminUsersFailure`.
        case failed(String)
    }

    enum HistoryState: Equatable {
        case loading
        case failed(String)
        case loaded([AdminUserShiftDay])
    }

    /// L'ordine dei turni nei selettori, come sulla web.
    static let shiftOptions: [AdminMemberShiftType] = [.morning, .afternoon, .night, .full]
    /// Da quanti team in su il selettore si può cercare per nome.
    static let searchableTeamCount = 8

    let userId: String
    let owner: AdminUsersViewModel
    let reloadDetails: @MainActor () async -> Void

    // MARK: - Team (per i selettori)

    private(set) var teams: [AdminMemberTeamOption] = []
    var teamsState: TeamsState = .idle

    // MARK: - Sposta oggi

    var moveShift: AdminMemberShiftType = .full
    var moveShiftTouched = false
    var isMoving = false

    // MARK: - Pianificazione

    /// Parte da oggi (giorno UTC), con la mezzanotte locale di quel giorno.
    var scheduleDate = AdminMemberDay.date(from: AdminMemberDay.utcToday()) ?? .now
    var scheduleShift: AdminMemberShiftType = .full
    var scheduleTeam: AdminMemberTeamOption?
    var isScheduling = false

    // MARK: - Cronologia

    var history: HistoryState = .loading
    var shiftToRemove: AdminMemberShift?
    var isRemoving = false

    init(userId: String, owner: AdminUsersViewModel, reloadDetails: @escaping @MainActor () async -> Void) {
        self.userId = userId
        self.owner = owner
        self.reloadDetails = reloadDetails
    }

    // MARK: - Chi guarda

    var canAssignShifts: Bool { owner.viewer.canAssignShifts }

    var membersAPI: AdminMembersAPI { AdminMembersAPI(api: owner.backend.api) }

    // MARK: - Caricamento

    /// La cronologia e, per chi può assegnare turni, i team dei selettori.
    func load() async {
        async let loadedTeams: Void = loadTeams()
        await loadHistory()
        await loadedTeams
    }

    func loadTeams(force: Bool = false) async {
        guard canAssignShifts, teamsState != .loading else { return }
        if teamsState == .loaded, !force { return }
        teamsState = .loading
        do {
            let rows = try await AdminLookupsAPI.teams(owner.backend.api, plantId: nil)
            teams = rows
                .map { AdminMemberTeamOption(id: $0.id, name: $0.name, isAdHoc: false) }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            teamsState = .loaded
        } catch {
            guard let failure = AdminUsersFailure.from(error, backend: owner.backend) else {
                // Annullata: alla prossima apertura si riprova.
                teamsState = .idle
                return
            }
            teamsState = .failed(failure.message)
            await owner.absorb(failure)
        }
    }

    // MARK: - Team nei selettori

    var teamsAreSearchable: Bool { teams.count >= Self.searchableTeamCount }

    /// I team il cui nome contiene `query` (senza badare a maiuscole e accenti); senza ricerca, tutti.
    func teams(matching query: String) -> [AdminMemberTeamOption] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return teams }
        return teams.filter { $0.name.localizedStandardContains(text) }
    }

    // MARK: - Scritture

    /// POST /v1/member-assignments. `true` se riuscita; altrimenti mostra `failure` e lascia fare a `absorb`.
    func assign(team: AdminMemberTeamOption, date: String, shift: AdminMemberShiftType, failure message: String) async -> Bool {
        let body = AdminMemberAssignmentCreate(userId: userId, teamId: team.id, shiftDate: date, shiftType: shift.rawValue)
        do {
            try await membersAPI.assign(body)
            return true
        } catch {
            await report(error, as: message)
            return false
        }
    }

    /// Un rifiuto: l'avviso del contratto (`nil` = annullata o sessione scaduta: niente) e i diritti riletti se serve.
    func report(_ error: any Error, as message: String) async {
        guard let failure = AdminUsersFailure.from(error, backend: owner.backend) else { return }
        owner.show(message, isError: true)
        await owner.absorb(failure)
    }
}
