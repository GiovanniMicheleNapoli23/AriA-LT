//
//  AdminPeopleViewer.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Chi guarda Members, ricavato una volta dal backend: chi è, che ruolo ha in azienda, i diritti di /v1/me e
//  il suo ruolo alto. Le regole di AdminMemberRules decidono solo da qui.
//

import Foundation

nonisolated struct AdminPeopleViewer: Equatable, Sendable {
    /// `nil`: non si sa chi è chi guarda. Allora nessuna azione di stato o di rimozione su nessuno (mai "non è lui").
    let userId: String?
    /// `myRole` dell'azienda attiva: `owner`, `admin`, `member`.
    let membershipRole: String?
    let rights: AriaRights
    let canManageRoles: Bool
    /// Il ruolo alto attivo di chi guarda; `nil` per owner, admin e ruoli base.
    let ownRoleId: String?

    init(userId: String? = nil, membershipRole: String? = nil, rights: AriaRights = .unrestricted,
         canManageRoles: Bool = false, ownRoleId: String? = nil) {
        self.userId = userId
        self.membershipRole = membershipRole
        self.rights = rights
        self.canManageRoles = canManageRoles
        self.ownRoleId = ownRoleId
    }

    /// Owner o admin dell'azienda: è `myRole`, oppure lo dice il server nel blocco `access`.
    var isAdmin: Bool { membershipRole == "owner" || membershipRole == "admin" || rights.isCompanyAdmin == true }

    var isOwner: Bool { membershipRole == "owner" }
}

extension AdminPeopleViewer {
    @MainActor
    init(backend: AriaBackend) {
        let company = backend.companies.first { $0.id == backend.activeCompanyId }
        let role = backend.access?.role
        self.init(userId: backend.mobileAccount?.id,
                  membershipRole: company?.myRole ?? backend.membership?.role,
                  rights: backend.rights,
                  canManageRoles: backend.access?.canManageRoles ?? false,
                  ownRoleId: role?.set == "high" && role?.enabled == true ? role?.id : nil)
    }
}
