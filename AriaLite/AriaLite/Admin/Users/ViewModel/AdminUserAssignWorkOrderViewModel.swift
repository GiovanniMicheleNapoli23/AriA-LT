//
//  AdminUserAssignWorkOrderViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il foglio "Assign a work order" (§5.4): gli ordini pianificati che nessuno tiene ancora (stato `planned`,
//  senza `assigned_to_user_id` e con `assigned_to` vuoto), cercabili per titolo. Il tocco manda l'assegnazione
//  tramite la scheda della persona, che ha il blocco delle scritture e gli avvisi.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminUserAssignWorkOrderViewModel {
    private let owner: AdminUsersViewModel
    /// L'assegnazione dell'ordine con l'id dato: `true` se è andata.
    private let assign: @MainActor (String) async -> Bool

    private(set) var orders: [AdminWorkOrder] = []
    private(set) var isLoading = true
    private(set) var loadFailed = false
    private(set) var isAssigning = false
    /// L'ordine è stato assegnato: il foglio si chiude.
    private(set) var isDone = false
    var query = ""

    init(owner: AdminUsersViewModel, assign: @escaping @MainActor (String) async -> Bool) {
        self.owner = owner
        self.assign = assign
    }

    /// Gli ordini pianificati senza nessuno, filtrati dalla ricerca per titolo.
    var visibleOrders: [AdminWorkOrder] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return orders.filter { text.isEmpty || $0.title.localizedCaseInsensitiveContains(text) }
    }

    /// "No planned work orders are waiting for someone." (anche quando la ricerca non trova niente, come sul web).
    var isEmpty: Bool { !isLoading && !loadFailed && visibleOrders.isEmpty }

    func load() async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }
        do {
            let planned = try await AdminWorkOrdersAPI(api: owner.backend.api)
                .list(AdminWorkOrderQuery(status: .planned, limit: 100), scope: "all")
            orders = planned.filter { order in
                order.assignedToUserId == nil
                    && (order.assignedTo ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        } catch {
            if let failure = AdminUsersFailure.from(error, backend: owner.backend) {
                loadFailed = true
                await owner.absorb(failure)
            }
        }
    }

    func pick(_ order: AdminWorkOrder) {
        guard !isAssigning else { return }
        isAssigning = true
        Task {
            defer { isAssigning = false }
            if await assign(order.id) {
                isDone = true
            } else {
                // Un altro può averlo preso nel frattempo: si rilegge.
                await load()
            }
        }
    }
}
