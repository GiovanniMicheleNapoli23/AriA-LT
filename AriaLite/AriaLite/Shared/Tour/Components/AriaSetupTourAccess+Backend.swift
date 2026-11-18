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
        let viewer = AdminPeopleViewer(backend: backend)
        self.init(
            offered: offered,
            hasSite: AdminDocumentsViewModel.canUpload(backend),
            canGovern: viewer.isAdmin,
            canInvite: AdminMemberRules.canCreate(viewer),
            canCreateTeam: backend.rights.can(.create, in: .teams),
            canConnect: AdminMarketplaceViewModel.canManage(backend)
        )
    }
}
