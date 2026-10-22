//
//  AdminTeamDetailViewModel+Members.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Aggiungere e togliere membri dal dettaglio di una squadra (POST e DELETE /v1/teams/{id}/members). Dopo ogni
//  modifica si rilegge la squadra e il suo carico.
//

import Foundation

extension AdminTeamDetailViewModel {
    func startAddingMember() {
        addMemberModel = AdminTeamAddMemberViewModel(detail: self)
    }

    func confirmRemoval(of member: AdminTeamMember) {
        memberPendingRemoval = member
    }

    /// Il testo della conferma: chi si toglie e da dove.
    func removalMessage(for member: AdminTeamMember) -> String {
        String(localized: "\(name(of: member)) will be removed from \(team.title).")
    }

    /// Il membro arriva dalla conferma: il binding del dialogo può azzerare `memberPendingRemoval` prima
    /// dell'azione.
    func remove(_ member: AdminTeamMember) async {
        guard let memberId = member.membershipId, !isRemovingMember else { return }
        memberPendingRemoval = nil
        isRemovingMember = true
        defer { isRemovingMember = false }
        do {
            try await api.removeMember(teamId: team.id, memberId: memberId)
            team.members.removeAll { $0.id == member.id }
            owner.didSave(team)
            await reloadWorkload()
        } catch {
            if let failure = AdminTeamsFailure.from(error, action: .write, backend: owner.backend) {
                memberError = failure.message
            }
        }
    }

    /// Un membro aggiunto: entra nella scheda e il carico si rilegge (cambia la capacità).
    func didAdd(_ member: AdminTeamMember) async {
        team.members.removeAll { $0.id == member.id || ($0.userId != nil && $0.userId == member.userId) }
        team.members.append(member)
        owner.didSave(team)
        await reloadWorkload()
    }

    private func reloadWorkload() async {
        guard let fresh = try? await api.workload(teamId: team.id) else { return }
        workload = fresh
        workloadMessage = nil
        owner.didLoad(workload: fresh, for: team.id)
    }
}
