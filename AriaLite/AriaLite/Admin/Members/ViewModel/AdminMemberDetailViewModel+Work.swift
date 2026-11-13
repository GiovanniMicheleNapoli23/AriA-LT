//
//  AdminMemberDetailViewModel+Work.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Il blocco "Lavoro" della scheda: i turni (assegna e togli solo dove il server lo accetta) e gli ordini aperti
//  assegnati alla persona, con i risultati dei passi, per chi ha la sezione Work Orders.
//

import Foundation

extension AdminMemberDetailViewModel {
    // MARK: - Turni

    /// Admin sempre; un ruolo con `assign_shifts` solo su un member con ruolo Low o senza ruolo.
    var canAssignShifts: Bool {
        member.map { AdminMemberRules.canAssignShifts(viewer, $0) } ?? false
    }

    func startAssigning() {
        guard canAssignShifts, let member else { return }
        assignForm = AdminMemberAssignShiftViewModel(member: member, owner: self)
    }

    // MARK: - Ordini aperti

    /// Gli ordini e i risultati dei passi li vede chi ha la sezione Work Orders.
    var canSeeOrders: Bool { backend.rights.has(.workOrders) }

    /// Sempre con `scope=all` (lo fa la chiamata): senza, per chi ha un ruolo il server mostrerebbe gli ordini di lui.
    func loadOrders() async {
        guard canSeeOrders else {
            orders = []
            hasLoadedOrders = false
            ordersError = nil
            return
        }
        do {
            let rows = try await backend.api.call(AdminMobileUsersAPI.openWorkOrders(userId: userId))
            orders = rows.items
            hasLoadedOrders = true
            ordersError = nil
        } catch {
            if let failure = AdminMembersFailure.from(error, action: .read, backend: backend) {
                ordersError = failure.message
            }
        }
    }

    func makeStepReportsViewModel(for order: AdminMobileUserWorkOrder) -> AdminMobileUserStepReportsViewModel {
        AdminMobileUserStepReportsViewModel(backend: backend, order: order)
    }
}
