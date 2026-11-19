//
//  AdminUsersViewer.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Chi guarda la sezione Users, ricavato una volta dal blocco `access` di GET /v1/me (§2): titolare, titolare di un
//  ruolo alto che gestisce i ruoli, o chi ha soltanto la sezione Members. Le regole di AdminUsersRules decidono da qui.
//

import Foundation

nonisolated struct AdminUsersViewer: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        /// `access.admin`: vede e cambia tutto, con i limiti su se stesso (§5.1).
        case owner
        /// Ruolo alto con `canManageRoles`: cambia il livello entro i ruoli bassi che il suo ruolo ha creato.
        case highHolder
        /// Ha solo la sezione Members: guarda.
        case otherHolder
    }

    /// `nil`: non si sa chi è. Allora nessuna azione "su se stessi" si riconosce e Suspend/Remove restano nascosti.
    let userId: String?
    let kind: Kind
    /// L'azienda non usa i ruoli (`access.model` è `legacy`): "Member" al posto di "No role".
    let legacy: Bool
    /// Il ruolo di chi guarda (`access.role.id`).
    let ownRoleId: String?
    /// `assign_shifts` della sezione Members, o titolare.
    let canAssignShifts: Bool

    init(userId: String?, kind: Kind, legacy: Bool = false, ownRoleId: String? = nil, canAssignShifts: Bool? = nil) {
        self.userId = userId
        self.kind = kind
        self.legacy = legacy
        self.ownRoleId = ownRoleId
        self.canAssignShifts = canAssignShifts ?? (kind == .owner)
    }

    init(userId: String?, access: AriaAccess?) {
        let kind: Kind
        if access?.admin == true {
            kind = .owner
        } else if access?.role?.set == "high", access?.canManageRoles == true {
            kind = .highHolder
        } else {
            kind = .otherHolder
        }
        let shifts = access?.sections[AriaSection.members.rawValue]?.actions.contains(AriaSectionAction.assignShifts.rawValue) ?? false
        self.init(userId: userId, kind: kind, legacy: access?.model == "legacy", ownRoleId: access?.role?.id,
                  canAssignShifts: kind == .owner || shifts)
    }

    var isOwner: Bool { kind == .owner }

    /// La persona è chi guarda.
    func isSelf(_ row: AdminUserRow) -> Bool {
        guard let userId else { return false }
        return userId == row.userId
    }
}

extension AdminUsersViewer {
    @MainActor
    init(backend: AriaBackend) {
        self.init(userId: backend.mobileAccount?.id, access: backend.access)
    }
}
