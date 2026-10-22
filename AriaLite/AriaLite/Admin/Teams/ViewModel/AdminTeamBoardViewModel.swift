//
//  AdminTeamBoardViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La bacheca di una squadra (pagina /board della web): gli ordini della squadra scelta in colonne per stato. Su
//  telefono si sceglie una colonna alla volta, su schermi larghi si vedono affiancate. Spostamenti in
//  AdminTeamBoardViewModel+Moves.
//

import Foundation
import Observation

/// Dove porta il tocco su "Board": una squadra precisa, o la prima dell'elenco.
struct AdminTeamBoardRoute: Hashable {
    let teamId: String?
}

@MainActor
@Observable
final class AdminTeamBoardViewModel {
    let owner: AdminTeamsViewModel

    private(set) var teamId: String?
    /// Le modifica anche gli spostamenti (+Moves): niente `private(set)`.
    var orders: [AdminTeamWorkOrder] = []
    var selectedStatus: AdminTeamWorkOrderStatus = .planned

    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var failure: AdminTeamsFailure?

    // Spostamenti (vedi +Moves)
    var moveError: String?
    var orderPendingCancel: AdminTeamWorkOrder?
    @ObservationIgnored var movingIds: Set<String> = []
    @ObservationIgnored private var generation = 0

    var isShowingMoveError: Bool {
        get { moveError != nil }
        set { if !newValue { moveError = nil } }
    }

    init(owner: AdminTeamsViewModel, teamId: String?) {
        self.owner = owner
        self.teamId = teamId ?? owner.visibleTeams.first?.id
    }

    var api: AdminTeamsAPI { owner.api }

    // MARK: - Squadre

    /// Le squadre fra cui scegliere, in ordine di nome.
    var teams: [AdminTeam] { owner.teams.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending } }

    var team: AdminTeam? { teams.first { $0.id == teamId } }

    var teamTitle: String { team?.title ?? String(localized: "Choose a team") }

    func selectTeam(_ id: String) {
        guard id != teamId else { return }
        teamId = id
        orders = []
        hasLoaded = false
        failure = nil
        Task { await load() }
    }

    // MARK: - Caricamento

    func loadIfNeeded() async {
        if !hasLoaded { await load() }
    }

    func load() async {
        guard let id = teamId else { return }
        generation += 1
        let current = generation
        isLoading = true
        defer { if current == generation { isLoading = false } }
        do {
            let rows = try await api.workOrders(teamId: id)
            guard current == generation else { return }
            orders = rows
            failure = nil
            if !hasLoaded { selectFirstFilledColumn() }
            hasLoaded = true
        } catch {
            guard current == generation else { return }
            if let failure = AdminTeamsFailure.from(error, action: .read, backend: owner.backend) {
                self.failure = failure
            }
        }
    }

    /// La prima volta si apre una colonna con qualcosa dentro, non una vuota.
    private func selectFirstFilledColumn() {
        guard !orders.contains(where: { $0.status == selectedStatus }) else { return }
        let filled = AdminTeamWorkOrderStatus.known.first { status in orders.contains { $0.status == status } }
        guard let first = filled else { return }
        selectedStatus = first
    }

    // MARK: - Colonne

    /// Le colonne del flusso, più "Other" solo se ci sono ordini con uno stato che non conosciamo.
    var columns: [AdminTeamWorkOrderStatus] {
        AdminTeamWorkOrderStatus.known + (orders.contains { $0.status == .unknown } ? [.unknown] : [])
    }

    func count(in status: AdminTeamWorkOrderStatus) -> Int {
        orders.filter { $0.status == status }.count
    }

    /// Le card di una colonna: prima le più urgenti.
    func cards(in status: AdminTeamWorkOrderStatus) -> [AdminTeamBoardCard] {
        orders.filter { $0.status == status }
            .sorted {
                if $0.priority.rank != $1.priority.rank { return $0.priority.rank < $1.priority.rank }
                return ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
            }
            .map(card)
    }

    private func card(_ order: AdminTeamWorkOrder) -> AdminTeamBoardCard {
        AdminTeamBoardCard(
            order: order,
            assignee: owner.person(id: order.assignedUserId)?.displayName,
            due: order.dueDate.map { $0.formatted(date: .abbreviated, time: .omitted) },
            isOverdue: order.isOverdue(),
            isBusy: movingIds.contains(order.id)
        )
    }

    var isEmpty: Bool { hasLoaded && orders.isEmpty }
}

/// Quello che una card della bacheca mostra, già pronto.
struct AdminTeamBoardCard: Identifiable, Hashable {
    let order: AdminTeamWorkOrder
    let assignee: String?
    let due: String?
    let isOverdue: Bool
    let isBusy: Bool

    var id: String { order.id }
}
