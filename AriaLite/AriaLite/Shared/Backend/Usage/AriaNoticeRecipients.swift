//
//  AriaNoticeRecipients.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  GET e PUT /v1/usage/notice-recipients: chi, oltre ai titolari, riceve gli avvisi d'uso. Solo per i titolari. La
//  lista dei membri serve anche a dare un nome agli id di `by_user` e dello storico del tetto. Lettura tollerante:
//  un membro illeggibile si scarta, un campo illeggibile vale `nil`.
//

import Foundation

nonisolated struct AriaNoticeRecipients: Decodable, Sendable, Equatable {
    /// Un membro attivo dell'azienda.
    nonisolated struct Member: Decodable, Sendable, Equatable {
        /// Senza id il membro si scarta.
        var userId: String
        var email: String?
        var name: String?
        var role: String?
        /// Il suo ruolo è sempre avvisato (`default`).
        var isDefault = false
        /// È stato aggiunto qui (`added`).
        var isAdded = false

        private enum CodingKeys: String, CodingKey {
            case email, name, role, added
            case userId = "user_id", isDefault = "default"
        }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            userId = try c.decode(String.self, forKey: .userId)
            email = c.ariaLenient(.email)
            name = c.ariaLenient(.name)
            role = c.ariaLenient(.role)
            isDefault = c.ariaLenient(.isDefault) ?? false
            isAdded = c.ariaLenient(.added) ?? false
        }

        /// Il nome da mostrare: il nome, altrimenti l'email.
        var displayName: String? {
            [name, email].lazy.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
        }
    }

    /// Gli id aggiunti oltre ai ruoli sempre avvisati.
    var userIds: [String] = []
    var defaultRoles: [String] = []
    var members: [Member] = []

    private enum CodingKeys: String, CodingKey {
        case members
        case userIds = "user_ids", defaultRoles = "default_roles"
    }

    init() {}

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userIds = c.ariaLenient([String].self, .userIds) ?? []
        defaultRoles = c.ariaLenient([String].self, .defaultRoles) ?? []
        members = (c.ariaLenient([AriaLenient<Member>].self, .members) ?? []).compactMap(\.value)
    }
}

/// Il body di PUT /v1/usage/notice-recipients: sostituisce tutta la lista degli aggiunti (vuota: nessuno).
nonisolated struct AriaNoticeRecipientsRequest: Encodable, Sendable, Equatable {
    var userIds: [String]

    private enum CodingKeys: String, CodingKey { case userIds = "user_ids" }

    init(userIds: [String]) {
        self.userIds = userIds
    }
}
