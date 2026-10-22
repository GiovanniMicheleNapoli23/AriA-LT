//
//  AdminMobileUsersResponse.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La risposta di GET …/mobile-users: i posti della licenza (usati su totali) e gli operatori.
//  Una riga illeggibile si salta, le altre restano.
//

import Foundation

nonisolated struct AdminMobileUserSeats: Decodable, Sendable, Hashable {
    let used: Int
    let total: Int

    var isFull: Bool { total > 0 && used >= total }
    /// 0…1 per la barra.
    var fraction: Double { total > 0 ? min(Double(used) / Double(total), 1) : 0 }
}

nonisolated struct AdminMobileUsersResponse: Decodable, Sendable {
    let seats: AdminMobileUserSeats?
    let operators: [AdminMobileUser]

    private enum CodingKeys: String, CodingKey { case seats, operators }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        seats = try? c.decodeIfPresent(AdminMobileUserSeats.self, forKey: .seats)
        operators = (try? c.decodeIfPresent(AriaLossyArray<AdminMobileUser>.self, forKey: .operators))?.items ?? []
    }
}
