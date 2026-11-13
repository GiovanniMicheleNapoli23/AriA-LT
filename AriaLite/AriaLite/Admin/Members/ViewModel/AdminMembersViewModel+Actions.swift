//
//  AdminMembersViewModel+Actions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le azioni dell'elenco: apertura del modulo "New person", cosa fare a creazione riuscita (si apre la scheda
//  della persona), l'apertura di una scheda e l'elenco dei team per i turni.
//

import Foundation

extension AdminMembersViewModel {
    // MARK: - Modulo

    /// Il "+" dell'elenco: solo owner e admin.
    func startCreatingMember() {
        guard canCreate else { return }
        newMemberForm = AdminMemberCreateViewModel(owner: self)
    }

    /// Persona creata: si chiude il foglio e si apre la sua scheda, con gli avvisi del caso.
    func didCreate(_ result: AdminMemberCreationResult) {
        creationNotices[result.userId] = result.notices
        newMemberForm = nil
        open(result.userId)
    }

    /// Apre la scheda di una persona (anche dal foglio di creazione, per chi c'è già nell'elenco).
    func open(_ userId: String) {
        newMemberForm = nil
        let route = AdminMemberRoute(userId: userId)
        guard path.last != route else { return }
        path.append(route)
    }

    /// Gli avvisi dell'ultima creazione per quella persona: si leggono una volta sola.
    func takeCreationNotices(for userId: String) -> [AdminMemberCreationNotice] {
        creationNotices.removeValue(forKey: userId) ?? []
    }

    // MARK: - Team

    func invalidateTeams() {
        teamsCompanyId = nil
    }

    /// I team per scegliere dove assegnare un turno: si scaricano una volta per azienda. Chi non è admin non ha
    /// la sezione Teams: legge `GET /v1/lookups/teams`, non `GET /v1/teams`.
    func loadTeamsIfNeeded() async {
        guard teamsCompanyId != backend.activeCompanyId || teams.isEmpty, !isLoadingTeams else { return }
        let company = backend.activeCompanyId
        let isAdmin = viewer.isAdmin
        isLoadingTeams = true
        defer { isLoadingTeams = false }
        do {
            let fresh: [AdminMemberTeamOption]
            if isAdmin {
                fresh = try await AdminMembersAPI(api: backend.api).teams()
            } else {
                fresh = try await AdminLookupsAPI.teams(backend.api, plantId: nil)
                    .map { AdminMemberTeamOption(id: $0.id, name: $0.name, isAdHoc: false) }
            }
            guard company == backend.activeCompanyId else { return }
            teams = fresh.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            teamsCompanyId = company
            teamsFailure = nil
        } catch {
            if let failure = AdminMembersFailure.from(error, action: .read, backend: backend) { teamsFailure = failure }
        }
    }
}
