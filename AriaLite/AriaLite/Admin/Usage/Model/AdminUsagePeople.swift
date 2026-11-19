//
//  AdminUsagePeople.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Come si dà un nome a un id di persona (`by_user`, storico del tetto): un titolare lo cerca fra i membri attivi di
//  GET /v1/usage/notice-recipients, un membro conosce solo sé stesso. Finché i membri si leggono il nome è un
//  segnaposto, mai "Former member".
//

import Foundation

nonisolated enum AdminUsagePersonName: Sendable, Equatable {
    /// I membri si stanno leggendo: un segnaposto.
    case loading
    /// Il nome della persona (il nome, altrimenti l'email).
    case name(String)
    /// L'elenco dei membri non si è letto: "Name unavailable".
    case unavailable
    /// L'elenco è letto e non ha questo id: "Former member".
    case formerMember
    /// `set_by` nullo nello storico del tetto: "AriA support".
    case supportAgent

    /// Il testo da scrivere; `nil` mentre si carica (la vista mette un segnaposto).
    var text: String? {
        switch self {
        case .loading: nil
        case .name(let name): name
        case .unavailable: String(localized: "Name unavailable")
        case .formerMember: String(localized: "Former member")
        case .supportAgent: String(localized: "AriA support")
        }
    }

    var isPending: Bool { self == .loading }
}

/// Chi può essere nominato: i membri letti (per un titolare) e chi ha fatto l'accesso.
nonisolated struct AdminUsagePeople: Sendable, Equatable {
    nonisolated enum MembersStatus: Sendable, Equatable {
        /// Non serve (un membro) o non ancora chiesto: per un titolare vale "si sta caricando".
        case notRead
        case loading, loaded, failed
    }

    var isOwner: Bool
    var membersStatus: MembersStatus
    /// Id → nome da mostrare (il nome, altrimenti l'email).
    var members: [String: String]
    /// Chi ha fatto l'accesso: id e nome (`backend.mobileAccount`).
    var meID: String?
    var meName: String?

    /// `userId` è chi ha fatto l'accesso: l'id coincide, o è un membro (che vede solo la propria riga).
    func isYou(_ userId: String?) -> Bool {
        guard let userId else { return false }
        if let meID, userId == meID { return true }
        return !isOwner
    }

    /// Il nome di una persona. `nil` è l'assistenza AriA (storico del tetto).
    func name(for userId: String?) -> AdminUsagePersonName {
        guard let userId else { return .supportAgent }
        if let known = members[userId] { return .name(known) }
        // Chi ha fatto l'accesso ha il suo nome anche senza l'elenco; un membro non ha altro.
        if isYou(userId), let meName { return .name(meName) }
        if !isOwner { return .unavailable }
        switch membersStatus {
        case .notRead, .loading: return .loading
        case .failed: return .unavailable
        case .loaded: return .formerMember
        }
    }
}
