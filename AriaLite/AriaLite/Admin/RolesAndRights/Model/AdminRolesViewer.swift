//
//  AdminRolesViewer.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Chi guarda Roles & Rights, ricavato una volta dal blocco `access` di GET /v1/me: tutto il resto della sezione
//  (cosa si vede, cosa si cambia, "Non incluso nel tuo ruolo") dipende da questo.
//

import Foundation

nonisolated enum AdminRolesViewer: Equatable, Sendable {
    /// Owner o admin: vede e cambia ogni ruolo, il ruolo predefinito, il ruolo di chiunque.
    case admin
    /// Chi ha un ruolo alto attivo: vede il suo ruolo (solo da guardare) e cambia i ruoli base che il suo ruolo ha
    /// creato, entro quello che il suo ruolo ha (`holds`: sezione → azioni).
    case high(roleId: String, holds: [String: Set<String>])

    /// `nil`: chi guarda non passa le condizioni della sezione (AriaRights.canOpenRolesAndRights).
    init?(access: AriaAccess?) {
        guard AriaRights(access: access).canOpenRolesAndRights, let access else { return nil }
        if access.admin {
            self = .admin
            return
        }
        guard let role = access.role, role.set == "high" else { return nil }
        let holds = access.sections.filter(\.value.granted).mapValues { Set($0.actions) }
        self = .high(roleId: role.id, holds: holds)
    }

    var isAdmin: Bool { self == .admin }

    /// Il ruolo di chi guarda (solo per un ruolo alto).
    var ownRoleId: String? {
        if case .high(let roleId, _) = self { roleId } else { nil }
    }

    /// Per un ruolo alto: il suo ruolo ha la sezione (e, con `action`, l'azione). Owner e admin hanno tutto.
    func holds(_ section: String, action: String? = nil) -> Bool {
        guard case .high(_, let holds) = self else { return true }
        guard let actions = holds[section] else { return false }
        return action.map(actions.contains) ?? true
    }

    /// Cambia quando va riletto l'elenco: un altro tipo di chi guarda, o un altro ruolo alto.
    var key: String {
        switch self {
        case .admin: "admin"
        case .high(let roleId, _): "high:\(roleId)"
        }
    }
}
