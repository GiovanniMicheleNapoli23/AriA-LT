//
//  AdminLookupsAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 03/11/26.
//
//  Le anagrafiche per chi ha un ruolo ("Roles & Rights"): GET /v1/lookups/people (`?field_only=true` per chi
//  lavora sul campo), GET /v1/lookups/teams e GET /v1/lookups/dispatch-candidates. Un membro con ruolo non può
//  chiamare /v1/users, /v1/members, /v1/teams né /v1/mobile-operators (servono `members` e `teams`): queste tre
//  rotte rispondono con quello che il suo ruolo gli lascia scegliere.
//  Forma (openapi del 05/11/26): array in camelCase. PersonLookup `id`, `name`, `fieldLabel`, `plantId`,
//  `isFieldWorker`; TeamLookup `id`, `name`, `memberIds`; DispatchCandidateLookup `id`, `name`, `specialties`,
//  `availability`, `availabilityAt`, `openCount`, `openMinutes`. Si legge senza errori (anche un oggetto con
//  l'array dentro, o chiavi snake_case): una riga senza `id` si scarta.
//  Le righe diventano i tipi che le viste già usano (persona, squadra, operatore): le viste non cambiano.
//

import Foundation

/// Una riga di una anagrafica, letta senza errori.
nonisolated struct AdminLookupRow: Sendable, Hashable {
    let id: String
    /// Il nome scritto dal server, se c'è.
    let fullName: String?
    let email: String?
    let role: String?
    let plantId: String?
    let memberCount: Int
    let isActive: Bool
    let availability: AriaAvailability?
    let availabilityAt: Date?
    let openCount: Int
    let openMinutes: Int
    let specialties: [String]

    /// Da una riga già in camelCase. Senza `id` la riga non si può scegliere: si scarta.
    init?(_ json: AriaJSON) {
        guard json.objectValue != nil,
              let id = (json["id"] ?? json["userId"] ?? json["teamId"])?.nonEmptyString else { return nil }
        self.id = id
        fullName = (json["name"] ?? json["fullName"] ?? json["displayName"])?.nonEmptyString
        email = json["email"]?.nonEmptyString
        role = json["role"]?.nonEmptyString
        plantId = json["plantId"]?.nonEmptyString
        let declaredMembers: Int? = json["memberCount"]?.doubleValue.map { Int($0) }
        memberCount = declaredMembers ?? (json["memberIds"] ?? json["members"])?.arrayValue.count ?? 0
        isActive = (json["isActive"] ?? json["active"])?.boolValue ?? true
        availability = json["availability"]?.stringValue.flatMap(AriaAvailability.init(rawValue:))
        availabilityAt = AriaDate.parse(json["availabilityAt"]?.stringValue)
        let open: Int? = json["openCount"]?.doubleValue.map { Int($0) }
        let minutes: Int? = json["openMinutes"]?.doubleValue.map { Int($0) }
        openCount = open ?? 0
        openMinutes = minutes ?? 0
        specialties = json["specialties"]?.arrayValue.compactMap(\.nonEmptyString) ?? []
    }

    /// Il nome da mostrare: quello del server, poi l'email, poi l'id.
    var name: String { fullName ?? email ?? id }

    var asUser: AdminWorkOrderUser {
        AdminWorkOrderUser(id: id, email: email ?? "", fullName: fullName, role: role, isActive: isActive)
    }

    var asTeam: AdminWorkOrderTeam {
        AdminWorkOrderTeam(id: id, name: name, plantId: plantId, memberCount: memberCount)
    }

    var asOperator: AdminWorkOrderFormOperator {
        AdminWorkOrderFormOperator(id: id, name: name, email: email ?? "", specialties: specialties,
                                   availability: availability, availabilityAt: availabilityAt,
                                   openCount: openCount, openMinutes: openMinutes)
    }
}

nonisolated enum AdminLookupsAPI {
    /// GET /v1/lookups/people. `fieldOnly`: solo chi lavora sul campo (assegnatari degli ordini).
    static func people(_ api: AriaAPIClient, fieldOnly: Bool) async throws -> [AdminLookupRow] {
        try await rows(api, "v1/lookups/people", fieldOnly ? [URLQueryItem(name: "field_only", value: "true")] : [])
    }

    /// GET /v1/lookups/teams.
    static func teams(_ api: AriaAPIClient, plantId: String?) async throws -> [AdminLookupRow] {
        try await rows(api, "v1/lookups/teams", plantId.map { [URLQueryItem(name: "plant_id", value: $0)] } ?? [])
    }

    /// GET /v1/lookups/dispatch-candidates: a chi si può assegnare un ordine, con disponibilità e carico se il server li dà.
    static func dispatchCandidates(_ api: AriaAPIClient) async throws -> [AdminLookupRow] {
        try await rows(api, "v1/lookups/dispatch-candidates", [])
    }

    private static func rows(_ api: AriaAPIClient, _ path: String, _ query: [URLQueryItem]) async throws -> [AdminLookupRow] {
        let json: AriaJSON = try await api.call(AriaEndpoint(method: "GET", path: path, query: query))
        return rows(from: json)
    }

    /// Le righe di una risposta: un array, o un oggetto che lo tiene in una delle chiavi note (o, in mancanza, nel primo array).
    static func rows(from json: AriaJSON) -> [AdminLookupRow] {
        let camel = json.camelCased()
        let list: [AriaJSON]
        switch camel {
        case .array(let items):
            list = items
        case .object(let object):
            let wrapped = ["items", "data", "people", "teams", "candidates", "results"].compactMap { object[$0] }
            let found = wrapped.first(where: isArray) ?? object.values.first(where: isArray)
            list = found?.arrayValue ?? []
        default:
            list = []
        }
        return list.compactMap(AdminLookupRow.init)
    }

    private static func isArray(_ json: AriaJSON) -> Bool {
        if case .array = json { return true }
        return false
    }
}

// MARK: Dalle righe ai tipi delle viste

nonisolated extension AdminWorkOrderUser {
    init(id: String, email: String, fullName: String?, role: String?, isActive: Bool) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.role = role
        self.isActive = isActive
    }
}

nonisolated extension AdminWorkOrderTeam {
    init(id: String, name: String, plantId: String?, memberCount: Int) {
        self.id = id
        self.name = name
        self.plantId = plantId
        self.memberCount = memberCount
    }
}

nonisolated extension AdminWorkOrderFormOperator {
    init(id: String, name: String, email: String, specialties: [String], availability: AriaAvailability?,
         availabilityAt: Date?, openCount: Int, openMinutes: Int) {
        self.id = id
        self.name = name
        self.email = email
        self.specialties = specialties
        self.availability = availability
        self.availabilityAt = availabilityAt
        self.openCount = openCount
        self.openMinutes = openMinutes
    }
}
