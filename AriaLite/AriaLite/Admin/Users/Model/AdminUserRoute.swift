//
//  AdminUserRoute.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda di una persona nel NavigationStack di Users: basta l'id, la scheda rilegge la riga dall'elenco.
//

import Foundation

nonisolated struct AdminUserRoute: Hashable, Sendable {
    let userId: String
}
