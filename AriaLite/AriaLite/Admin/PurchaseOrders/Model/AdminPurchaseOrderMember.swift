//
//  AdminPurchaseOrderMember.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il membro che ha approvato un ordine, letto da GET /v1/members/{user_id} (MemberResponse).
//  Tutti i campi sono facoltativi: serve solo a mostrare un nome.
//

import Foundation

nonisolated struct AdminPurchaseOrderMember: Decodable, Sendable, Hashable {
    var id: String?
    var fullName: String?
    var email: String?

    /// Il nome da mostrare: il nome completo, altrimenti l'email.
    var displayName: String? {
        if let fullName, !fullName.isEmpty { return fullName }
        if let email, !email.isEmpty { return email }
        return nil
    }
}
