//
//  AdminUserRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Una persona della sezione Users come la manda GET /v1/companies/{id}/users (UserRow, camelCase), e la pagina
//  intera: le persone, i posti e i titolari (§3.1). Lettura tollerante: obbligatorio solo `userId`; quel che manca
//  vale come dice il §9 (app accesa, non sul campo, niente disponibilità, niente "online").
//

import Foundation

nonisolated enum AdminUserLevel: String, Sendable, Hashable {
    case owner
    case member
}

nonisolated enum AdminUserStatus: String, Sendable, Hashable, CaseIterable {
    case active
    case suspended
    case invited
}

nonisolated enum AdminUserAvailability: String, Sendable, Hashable, CaseIterable {
    case available
    case busy
    case offDuty = "off_duty"
}

/// Il ruolo che la persona tiene: `set` è `high` o `low`; `enabled: false` è un ruolo in pausa.
nonisolated struct AdminUserRole: Sendable, Hashable {
    let id: String
    let name: String
    let set: String
    let enabled: Bool

    var isHigh: Bool { self.set == "high" }
}

/// Le ultime volte che si è visto, sul web e nell'app. Arriva solo a un titolare.
nonisolated struct AdminUserLastSeen: Sendable, Hashable {
    var web: String?
    var app: String?
}

nonisolated struct AdminUserRow: Decodable, Sendable, Identifiable, Hashable {
    let userId: String
    var name: String
    var email: String?
    var level: AdminUserLevel
    var role: AdminUserRole?
    var status: AdminUserStatus
    var appAccess: Bool
    var fieldWorker: Bool
    var availability: AdminUserAvailability?
    /// `nil`: non è di chi guarda vederlo (solo i titolari lo ricevono), o è un invito per email.
    var lastSeen: AdminUserLastSeen?
    /// Un invito per email ancora aperto: nessuna persona dietro, non si apre, si può solo revocare.
    var invitationId: String?

    var id: String { userId }

    init(userId: String, name: String = "", email: String? = nil, level: AdminUserLevel = .member,
         role: AdminUserRole? = nil, status: AdminUserStatus = .active, appAccess: Bool = true,
         fieldWorker: Bool = false, availability: AdminUserAvailability? = nil, lastSeen: AdminUserLastSeen? = nil,
         invitationId: String? = nil) {
        self.userId = userId
        self.name = name
        self.email = email
        self.level = level
        self.role = role
        self.status = status
        self.appAccess = appAccess
        self.fieldWorker = fieldWorker
        self.availability = availability
        self.lastSeen = lastSeen
        self.invitationId = invitationId
    }

    private enum CodingKeys: String, CodingKey {
        case userId, name, email, level, role, status, appAccess, fieldWorker, availability, lastSeen, invitationId
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func json(_ key: CodingKeys) -> AriaJSON? { try? c.decodeIfPresent(AriaJSON.self, forKey: key) }
        func text(_ key: CodingKeys) -> String? { json(key)?.nonEmptyString }
        guard let userId = text(.userId) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "User without id"))
        }
        self.userId = userId
        name = json(.name)?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        email = text(.email)
        level = text(.level).flatMap(AdminUserLevel.init(rawValue:)) ?? .member
        if let role = json(.role), let id = role["id"]?.nonEmptyString {
            self.role = AdminUserRole(id: id, name: role["name"]?.stringValue ?? "",
                                      set: role["set"]?.stringValue ?? "low",
                                      enabled: role["enabled"]?.boolValue ?? true)
        }
        status = text(.status).flatMap(AdminUserStatus.init(rawValue:)) ?? .active
        appAccess = json(.appAccess)?.boolValue ?? true
        fieldWorker = json(.fieldWorker)?.boolValue ?? false
        availability = text(.availability).flatMap(AdminUserAvailability.init(rawValue:))
        if let seen = json(.lastSeen), seen.objectValue != nil {
            lastSeen = AdminUserLastSeen(web: seen["web"]?.nonEmptyString, app: seen["app"]?.nonEmptyString)
        }
        invitationId = text(.invitationId)
    }

    // MARK: - Cosa è

    var isOwner: Bool { level == .owner }
    /// Un invito per email (non una persona aggiunta che non è ancora entrata).
    var isInvitation: Bool { invitationId != nil }
    /// La riga apre la scheda della persona.
    var opens: Bool { !isInvitation }

    /// Il nome, altrimenti l'email, altrimenti "Unnamed person".
    var displayName: String {
        if !name.isEmpty { return name }
        if let email, !email.isEmpty { return email }
        return String(localized: "Unnamed person")
    }

    /// Le iniziali per l'avatar.
    var initials: String {
        let words = displayName.split { !$0.isLetter && !$0.isNumber }
        let letters = words.count >= 2 ? words.prefix(2).compactMap(\.first) : Array(words.first?.prefix(2) ?? "?")
        return String(letters).uppercased()
    }
}

/// GET /v1/companies/{id}/users: tutti, i posti e i titolari. I conti vengono dal server, mai dalle righe.
nonisolated struct AdminUsersPage: Decodable, Sendable, Equatable {
    struct Seats: Sendable, Equatable {
        var used: Int
        /// `nil`: il piano non dice un tetto.
        var total: Int?
    }

    struct Owners: Sendable, Equatable {
        var count: Int
        var max: Int
    }

    var people: [AdminUserRow]
    var seats: Seats
    var owners: Owners

    init(people: [AdminUserRow] = [], seats: Seats = Seats(used: 0, total: nil), owners: Owners = Owners(count: 0, max: 3)) {
        self.people = people
        self.seats = seats
        self.owners = owners
    }

    private enum CodingKeys: String, CodingKey { case people, seats, owners }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        people = (try? c.decodeIfPresent(AriaLossyArray<AdminUserRow>.self, forKey: .people))?.items ?? []
        let seats = try? c.decodeIfPresent(AriaJSON.self, forKey: .seats)
        self.seats = Seats(used: seats?["used"]?.int ?? 0, total: seats?["total"]?.int)
        let owners = try? c.decodeIfPresent(AriaJSON.self, forKey: .owners)
        self.owners = Owners(count: owners?["count"]?.int ?? 0, max: owners?["max"]?.int ?? 3)
    }
}

private extension AriaJSON {
    /// Un numero intero (JSON non distingue interi e decimali).
    nonisolated var int: Int? { doubleValue.map { Int($0) } }
}
