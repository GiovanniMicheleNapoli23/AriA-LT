//
//  AdminMemberRoute.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  La destinazione "scheda di una persona" nel NavigationStack di Members (e di Roles & Rights): basta l'id,
//  la scheda rilegge la persona dall'elenco e dal server.
//

import Foundation

nonisolated struct AdminMemberRoute: Hashable, Sendable {
    let userId: String
}
