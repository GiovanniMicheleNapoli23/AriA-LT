//
//  AdminTeamBoardViewModel+Moves.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Gli spostamenti dalla bacheca: cambio di stato e passaggio a un'altra squadra (PATCH /v1/work-orders/{id}). La
//  card si muove subito e torna com'era se il server rifiuta. "Cancelled" chiede conferma.
//

import Foundation

extension AdminTeamBoardViewModel {
    /// Gli stati in cui si può portare l'ordine (non quello in cui è già).
    func statusChoices(for order: AdminTeamWorkOrder) -> [AdminTeamWorkOrderStatus] {
        AdminTeamWorkOrderStatus.moveTargets.filter { $0 != order.status }
    }

    /// Le altre squadre a cui passarlo.
    func teamChoices(for order: AdminTeamWorkOrder) -> [AdminTeam] {
        teams.filter { $0.id != teamId }
    }

    func move(_ order: AdminTeamWorkOrder, to status: AdminTeamWorkOrderStatus) {
        if status == .cancelled {
            orderPendingCancel = order
        } else {
            Task { await changeStatus(order, to: status) }
        }
    }

    func confirmCancel() {
        guard let order = orderPendingCancel else { return }
        orderPendingCancel = nil
        Task { await changeStatus(order, to: .cancelled) }
    }

    func cancelMessage(for order: AdminTeamWorkOrder) -> String {
        String(localized: "“\(order.title)” will be marked as cancelled.")
    }

    /// La card cambia colonna subito; se il server rifiuta torna com'era e si spiega perché.
    private func changeStatus(_ order: AdminTeamWorkOrder, to status: AdminTeamWorkOrderStatus) async {
        guard !movingIds.contains(order.id), let index = orders.firstIndex(where: { $0.id == order.id }) else { return }
        let original = orders[index]
        orders[index].status = status
        movingIds.insert(order.id)
        defer { movingIds.remove(order.id) }
        do {
            try await api.updateWorkOrder(id: order.id, AdminTeamWorkOrderPatch(status: status.rawValue))
            await owner.refreshWorkloads(for: [teamId].compactMap { $0 })
        } catch {
            if let at = orders.firstIndex(where: { $0.id == order.id }) { orders[at] = original }
            reportMoveFailure(error)
        }
    }

    /// Passa l'ordine a un'altra squadra: esce dalla bacheca di questa; se il server rifiuta rientra.
    func assign(_ order: AdminTeamWorkOrder, to target: AdminTeam) {
        Task { await reassign(order, to: target) }
    }

    private func reassign(_ order: AdminTeamWorkOrder, to target: AdminTeam) async {
        guard !movingIds.contains(order.id), let index = orders.firstIndex(where: { $0.id == order.id }) else { return }
        let original = orders[index]
        orders.remove(at: index)
        movingIds.insert(order.id)
        defer { movingIds.remove(order.id) }
        do {
            try await api.updateWorkOrder(id: order.id, AdminTeamWorkOrderPatch(assignedToTeamId: target.id))
            await owner.refreshWorkloads(for: [teamId, target.id].compactMap { $0 })
        } catch {
            orders.insert(original, at: min(index, orders.count))
            reportMoveFailure(error)
        }
    }

    private func reportMoveFailure(_ error: any Error) {
        if let failure = AdminTeamsFailure.from(error, action: .write, backend: owner.backend) {
            moveError = failure.message
        }
    }
}
