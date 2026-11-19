//
//  AdminRoleDeleteViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  "Eliminare {ruolo}?". Nessuno lo ha: si elimina senza body. Qualcuno lo ha: prima si sceglie dove vanno (un
//  ruolo o "Nessun ruolo") e si manda `moveTo`. Se nel frattempo qualcuno l'ha preso (409 `role_has_members`) si
//  passa alla scelta; se il ruolo scelto è sparito o in pausa dopo la rilettura, si chiede di nuovo.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminRoleDeleteViewModel: Identifiable {
    enum Choice: Hashable {
        case role(String)
        case noRole
    }

    let roleId: String
    let owner: AdminRolesViewModel
    /// Il nome all'apertura: resta nel titolo anche se il ruolo sparisce dall'elenco.
    let roleName: String

    /// Quante persone vanno spostate; 0 = nessuno ha il ruolo.
    private(set) var holders: Int
    var choice: Choice?
    private(set) var errorMessage: String?
    private(set) var isDeleting = false

    var id: String { roleId }

    init(role: AdminRole, owner: AdminRolesViewModel) {
        roleId = role.id
        roleName = role.name
        holders = role.holders
        self.owner = owner
    }

    private var role: AdminRole? { owner.role(id: roleId) }

    var asksWhereTo: Bool { holders > 0 }

    var moveFirstText: String {
        holders == 1 ? String(localized: "1 person holds this role. Choose the role they move to first.")
            : String(localized: "\(holders) people hold this role. Choose the role they move to first.")
    }

    var targets: [AdminRole] { role.map(owner.moveTargets(deleting:)) ?? [] }

    func label(_ target: AdminRole) -> String { target.name }

    var canConfirm: Bool { !isDeleting && role != nil && (!asksWhereTo || choice != nil) }

    /// Dopo ogni rilettura dell'elenco: un ruolo scelto che non si può più offrire non vale più.
    func rolesDidChange() {
        if let role, role.holders > holders { holders = role.holders }
        if case .role(let id)? = choice, !targets.contains(where: { $0.id == id }) { choice = nil }
    }

    /// `true`: la schermata si chiude.
    func confirm() async -> Bool {
        guard canConfirm, let role else { return false }
        isDeleting = true
        defer { isDeleting = false }
        errorMessage = nil
        let move: AdminRoleDeleteMove? = switch choice {
        case nil: nil
        case .noRole?: AdminRoleDeleteMove(moveTo: nil)
        case .role(let id)?: AdminRoleDeleteMove(moveTo: id)
        }
        let chosen = choice
        switch await owner.delete(role, move: asksWhereTo ? move : nil) {
        case .done:
            return true
        case .hasMembers:
            holders = max(1, owner.role(id: roleId)?.holders ?? 0)
            return false
        case .failed(let message):
            // Il ruolo scelto è sparito o in pausa: la scelta non vale più, si chiede di nuovo.
            if chosen != nil, choice == nil, owner.role(id: roleId) != nil {
                errorMessage = message
                return false
            }
            if let message { owner.show(message, isError: true) }
            return true
        case .nameTaken:
            return true
        }
    }
}
