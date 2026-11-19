//
//  AdminUserRequests.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  I body delle scritture della sezione Users. Una chiave sconosciuta è un 422: ogni body manda solo le sue.
//  Il livello (camelCase) scrive sempre `accessRoleId` per un membro, anche `null` (senza: 422 `role_required`).
//  POST /v1/users (snake_case) manda `access_role_id` solo per un ruolo scelto.
//

import Foundation

/// PUT …/members/{id}/level: `{"level":"owner"}` oppure `{"level":"member","accessRoleId":<id>|null}`.
nonisolated enum AdminUserLevelChange: Encodable, Sendable, Equatable {
    case owner
    /// `nil`: nessun ruolo (o "Member" in un'azienda senza ruoli).
    case member(roleId: String?)

    private enum CodingKeys: String, CodingKey { case level, accessRoleId }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .owner:
            try c.encode("owner", forKey: .level)
        case .member(let roleId):
            try c.encode("member", forKey: .level)
            // Mai `encodeIfPresent`: la chiave deve esserci anche quando è `null`.
            if let roleId { try c.encode(roleId, forKey: .accessRoleId) } else { try c.encodeNil(forKey: .accessRoleId) }
        }
    }
}

/// PUT …/app-access e …/field-worker: `{"on": true|false}`.
nonisolated struct AdminUserSwitch: Encodable, Sendable, Equatable {
    let on: Bool
}

/// PATCH /v1/members/{id} con il solo stato: `{"status":"suspended"|"active"}`.
nonisolated struct AdminUserStatusChange: Encodable, Sendable, Equatable {
    let status: String
}

/// PATCH /v1/members/{id} con le sole specialità, la lista intera.
nonisolated struct AdminUserSpecialtiesChange: Encodable, Sendable, Equatable {
    let specialties: [String]
}

/// POST /v1/users (header `Company-Id`, snake_case). `role` è l'etichetta (`technician`, `manager`), non il livello.
nonisolated struct AdminUserCreate: Encodable, Sendable, Equatable {
    var email: String
    var fullName: String
    var role: String
    /// `owner` o `member`.
    var level: String
    /// Solo per un ruolo scelto; `nil` non si scrive (Owner, "No role", "Member").
    var accessRoleId: String?
}

/// PATCH /v1/work-orders/{id}: dare un ordine pianificato a un lavoratore sul campo (§5.4).
nonisolated struct AdminUserWorkOrderAssignment: Encodable, Sendable, Equatable {
    let assignedToUserId: String
    let assignedTo: String
}
