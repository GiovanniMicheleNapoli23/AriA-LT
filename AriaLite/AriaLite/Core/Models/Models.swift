//
//  Models.swift
//  AriaLite
//
//  Created by Giovanni Michele on 19/03/26.
//

import Foundation

/// L'operatore che ha fatto l'accesso (account Aria).
struct User: Identifiable, Equatable, Codable {
    let id: UUID
    let username: String
    let name: String
}
