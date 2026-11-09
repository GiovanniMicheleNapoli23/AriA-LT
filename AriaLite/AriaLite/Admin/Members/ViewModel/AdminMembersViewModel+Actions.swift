//
//  AdminMembersViewModel+Actions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le azioni dell'elenco: apertura dei moduli (nuovo membro, team ad hoc), elenco dei team per i turni
//  e cosa fare quando una modifica è andata a buon fine.
//

import Foundation

extension AdminMembersViewModel {
    // MARK: - Moduli

    func startCreatingMember() {
        newMemberForm = AdminMemberCreateViewModel(owner: self)
    }

    func startCreatingAdHocTeam() {
        adHocTeamForm = AdminMemberAdHocTeamViewModel(owner: self)
    }

    /// Un membro creato: si rilegge l'elenco (la risposta non ha carico né team).
    func didCreateMember() async {
        await refresh()
    }

    /// Un team ad hoc creato: cambiano i team e i turni di oggi, quindi elenco e team si rileggono.
    func didCreateAdHocTeam() async {
        invalidateTeams()
        await refresh()
    }

    // MARK: - Team

    func invalidateTeams() {
        teamsCompanyId = nil
    }

    /// I team per scegliere dove assegnare un turno: si scaricano una volta per azienda.
    func loadTeamsIfNeeded() async {
        guard teamsCompanyId != backend.activeCompanyId || teams.isEmpty, !isLoadingTeams else { return }
        let company = backend.activeCompanyId
        isLoadingTeams = true
        defer { isLoadingTeams = false }
        do {
            let fresh = try await AdminMembersAPI(api: backend.api).teams()
            guard company == backend.activeCompanyId else { return }
            teams = fresh.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            teamsCompanyId = company
            teamsFailure = nil
        } catch {
            if let failure = AdminMembersFailure.from(error, action: .read, backend: backend) { teamsFailure = failure }
        }
    }
}
