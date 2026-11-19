//
//  AriaSetupTourAccess+Backend.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Ricava AriaSetupTourAccess dal backend con le stesse regole delle schermate indicate dai passi: ogni
//  Bool ripete quello che la schermata usa per mostrare il suo pulsante (nessuna regola nuova qui).
//

import Foundation

extension AriaSetupTourAccess {
    @MainActor
    init(backend: AriaBackend, offered: Set<AriaDestination>) {
        let company = backend.companies.first { $0.id == backend.activeCompanyId }
        let myRole = company?.myRole ?? backend.membership?.role
        let isAdmin = myRole == "owner" || myRole == "admin" || backend.rights.isCompanyAdmin == true
        self.init(
            offered: offered,
            hasSite: AdminDocumentsViewModel.canUpload(backend),
            canGovern: isAdmin,
            canInvite: AdminUsersViewer(backend: backend).isOwner,
            canCreateTeam: backend.rights.can(.create, in: .teams),
            canConnect: AdminMarketplaceViewModel.canManage(backend)
        )
    }
}
