//
//  AdminUsageMemberLimit.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda "Spending limit" che un membro legge al posto dei controlli di fatturazione (contratto 3.9), già scritta.
//

import Foundation

nonisolated struct AdminUsageMemberLimit: Sendable, Equatable {
    var title: String
    /// Il tetto in euro (un membro lo legge anche senza vedere gli altri importi).
    var amount: String
    /// "= 3,125 credits", quando il server lo manda.
    var creditsEquivalent: String?
    /// "Reached" oppure "In force".
    var chip: String
    var isReached: Bool
    /// "Your company is close to this limit." quando lo stato è `warned`.
    var warnedNote: String?
    /// "Until {day}, usage past the included credits stops. An owner can raise the limit.": raggiunto, su un piano che si ferma.
    var reachedNote: String?
    /// "Only owners can change this limit."
    var managedNote: String
}
