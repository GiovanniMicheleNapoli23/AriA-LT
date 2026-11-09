//
//  AdminTaskboardPersonGroup.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Le task di chi le esegue, pronte da mostrare: una persona (o un nome libero), una squadra senza persona,
//  oppure nessuno. Con quante sono in ritardo.
//

import Foundation

nonisolated struct AdminTaskboardPersonGroup: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable { case person, team, unassigned }

    let id: String
    let kind: Kind
    let name: String
    let items: [AdminWorkOrderRowItem]

    var overdueCount: Int { items.count(where: \.isOverdue) }

    /// Le iniziali per l'avatar: due lettere dal nome.
    var initials: String {
        let words = name.split { !$0.isLetter && !$0.isNumber }
        let letters = words.count >= 2 ? words.prefix(2).compactMap(\.first) : Array(words.first?.prefix(2) ?? "?")
        return String(letters).uppercased()
    }
}

/// Il pallino di un ordine nel calendario.
nonisolated enum AdminTaskboardDayTone: Hashable, Sendable {
    case open, overdue, closed
}
