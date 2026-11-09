//
//  AdminTeamDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di una squadra (pagina /teams/{id} della web): scheda, carico, membri e ordini. Scheda, carico e
//  ordini si scaricano insieme e ognuno fallisce per conto suo. Modifica ed eliminazione passano da qui; membri in
//  AdminTeamDetailViewModel+Members.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminTeamDetailViewModel {
    let owner: AdminTeamsViewModel
    /// Scheda e carico li aggiorna anche +Members: niente `private(set)`.
    var team: AdminTeam
    var workload: AdminTeamWorkload?
    private(set) var workOrders: [AdminTeamWorkOrder] = []

    private(set) var isLoading = false
    private(set) var hasLoadedOrders = false
    /// La scheda non si è aggiornata (resta quella dell'elenco).
    private(set) var failure: AdminTeamsFailure?
    var workloadMessage: String?
    private(set) var ordersMessage: String?

    var editForm: AdminTeamFormViewModel?
    var showsDeleteConfirmation = false
    private(set) var isDeleting = false
    var deleteError: String?
    var isShowingDeleteError: Bool {
        get { deleteError != nil }
        set { if !newValue { deleteError = nil } }
    }

    // Membri (vedi +Members)
    var addMemberModel: AdminTeamAddMemberViewModel?
    var memberPendingRemoval: AdminTeamMember?
    var isRemovingMember = false
    var memberError: String?
    var isShowingMemberError: Bool {
        get { memberError != nil }
        set { if !newValue { memberError = nil } }
    }

    init(team: AdminTeam, owner: AdminTeamsViewModel) {
        self.team = team
        self.owner = owner
        workload = owner.workloads[team.id]
    }

    var api: AdminTeamsAPI { owner.api }

    // MARK: - Caricamento

    func load() async {
        let api = api
        let id = team.id
        isLoading = true
        defer { isLoading = false }
        let teamTask = Task { try await api.team(id: id) }
        let workloadTask = Task { try await api.workload(teamId: id) }
        let ordersTask = Task { try await api.workOrders(teamId: id) }
        async let people: Void = owner.loadPeople()

        switch await teamTask.result {
        case .success(let fresh):
            team = fresh
            owner.didSave(fresh)
            failure = nil
        case .failure(let error):
            failure = AdminTeamsFailure.from(error, action: .read, backend: owner.backend)
        }
        switch await workloadTask.result {
        case .success(let fresh):
            workload = fresh
            workloadMessage = nil
            owner.didLoad(workload: fresh, for: id)
        case .failure(let error):
            workloadMessage = AdminTeamsFailure.from(error, action: .read, backend: owner.backend)?.message
        }
        switch await ordersTask.result {
        case .success(let rows):
            workOrders = rows.sorted(by: Self.urgency)
            hasLoadedOrders = true
            ordersMessage = nil
        case .failure(let error):
            ordersMessage = AdminTeamsFailure.from(error, action: .read, backend: owner.backend)?.message
        }
        await people
    }

    /// Prima gli aperti, poi per priorità e scadenza.
    private static func urgency(_ a: AdminTeamWorkOrder, _ b: AdminTeamWorkOrder) -> Bool {
        if a.status.isClosed != b.status.isClosed { return !a.status.isClosed }
        if a.priority.rank != b.priority.rank { return a.priority.rank < b.priority.rank }
        return (a.dueDate ?? .distantFuture) < (b.dueDate ?? .distantFuture)
    }

    // MARK: - Presentazione

    var plantName: String? { owner.plantName(for: team.plantId) }

    var memberCountText: String {
        String(localized: "\(team.members.count) members")
    }

    var openWorkOrders: [AdminTeamWorkOrder] { workOrders.filter { !$0.status.isClosed } }

    /// Il nome di un membro: dall'anagrafica, altrimenti l'id.
    func name(of member: AdminTeamMember) -> String {
        owner.person(id: member.userId)?.displayName ?? member.userId ?? String(localized: "Unknown person")
    }

    // MARK: - Modifica ed eliminazione

    func startEditing() {
        editForm = AdminTeamFormViewModel(mode: .edit(team), owner: owner) { [weak self] saved in
            self?.team = saved
        }
    }

    /// `true` se eliminata: il dettaglio si chiude.
    func delete() async -> Bool {
        guard !isDeleting else { return false }
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await api.delete(id: team.id)
            owner.didDelete(id: team.id)
            return true
        } catch {
            if let failure = AdminTeamsFailure.from(error, action: .write, backend: owner.backend) {
                if failure.isNotFound {
                    owner.didDelete(id: team.id)
                    return true
                }
                deleteError = failure.message
            }
            return false
        }
    }
}
