//
//  AdminRole.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Un ruolo come lo manda il server (RoleView di GET …/access/roles). Campi in camelCase. `editable` è la
//  risposta del server a "chi guarda può cambiarlo?": l'app la usa così com'è. `version` torna con ogni modifica.
//

import Foundation

nonisolated enum AdminRoleSet: String, Sendable, Codable, Hashable {
    case high
    case low
}

nonisolated struct AdminRole: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var set: AdminRoleSet
    /// `false`: in pausa, chi lo ha tiene solo la chat e le schermate sempre disponibili.
    var enabled: Bool
    /// Una chiave presente = sezione accesa; la sua lista = le azioni accese.
    var grants: [String: [String]]
    /// Il ruolo alto che ha creato questo ruolo base; `nil` per owner/admin o un ruolo iniziale.
    let ownerRoleId: String?
    let createdBy: String?
    let createdByName: String?
    var holders: Int
    var isDefault: Bool
    let exceedsOwner: Bool
    let editable: Bool
    let version: Int
    /// "manager" o "technician" per i due ruoli iniziali di ogni azienda.
    let seedKey: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, set, enabled, grants, ownerRoleId, createdBy, createdByName, holders, isDefault, exceedsOwner,
             editable, version, seedKey
    }

    init(id: String, name: String, set: AdminRoleSet, enabled: Bool = true, grants: [String: [String]] = [:],
         ownerRoleId: String? = nil, createdBy: String? = nil, createdByName: String? = nil, holders: Int = 0,
         isDefault: Bool = false, exceedsOwner: Bool = false, editable: Bool = true, version: Int = 1,
         seedKey: String? = nil) {
        self.id = id
        self.name = name
        self.set = set
        self.enabled = enabled
        self.grants = grants
        self.ownerRoleId = ownerRoleId
        self.createdBy = createdBy
        self.createdByName = createdByName
        self.holders = holders
        self.isDefault = isDefault
        self.exceedsOwner = exceedsOwner
        self.editable = editable
        self.version = version
        self.seedKey = seedKey
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        // Un livello sconosciuto vale "low": il ruolo che concede meno.
        set = (try? c.decodeIfPresent(AdminRoleSet.self, forKey: .set)) ?? .low
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        grants = (try? c.decodeIfPresent([String: [String]].self, forKey: .grants)) ?? [:]
        ownerRoleId = try c.decodeIfPresent(String.self, forKey: .ownerRoleId)
        createdBy = try c.decodeIfPresent(String.self, forKey: .createdBy)
        createdByName = try c.decodeIfPresent(String.self, forKey: .createdByName)
        holders = try c.decodeIfPresent(Int.self, forKey: .holders) ?? 0
        isDefault = try c.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        exceedsOwner = try c.decodeIfPresent(Bool.self, forKey: .exceedsOwner) ?? false
        // Senza il campo non si sa: meglio non offrire modifiche che il server rifiuterebbe.
        editable = try c.decodeIfPresent(Bool.self, forKey: .editable) ?? false
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        seedKey = try c.decodeIfPresent(String.self, forKey: .seedKey)
    }
}

/// GET …/access/roles
nonisolated struct AdminRoleList: Decodable, Sendable {
    let roles: [AdminRole]

    private enum CodingKeys: String, CodingKey { case roles }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        roles = try c.decodeIfPresent(AriaLossyArray<AdminRole>.self, forKey: .roles)?.items ?? []
    }
}
