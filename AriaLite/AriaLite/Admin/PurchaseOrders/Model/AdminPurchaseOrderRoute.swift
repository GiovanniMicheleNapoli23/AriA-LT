//
//  AdminPurchaseOrderRoute.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Dove porta un tocco nella sezione ordini di acquisto: per id, così il percorso non tiene copie dell'ordine.
//

import Foundation

nonisolated enum AdminPurchaseOrderRoute: Hashable, Sendable {
    case order(String)

    var id: String {
        switch self {
        case .order(let id): id
        }
    }
}
