//
//  AdminUsageNoticePeopleList.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il foglio "Sent to" di un avviso (contratto 5.4) già scritto: i ruoli avvisati e le persone nominate, scelte fra i membri
//  attivi. Una persona scelta che non è più un membro attivo sta in cima, spuntata e "Inactive", per poterla togliere.
//

import Foundation

nonisolated struct AdminUsageNoticePeopleList: Sendable, Equatable {
    var roles: [Role]
    /// Le persone nominate prendono il posto dei ruoli: finché ce n'è una i ruoli non si toccano.
    var rolesDisabled: Bool
    /// Scelte ma non più membri attivi.
    var former: [Person]
    /// I membri attivi che corrispondono alla ricerca.
    var people: [Person]

    nonisolated struct Role: Sendable, Equatable, Identifiable {
        /// `owner` o `member`.
        var role: String
        /// "Owners" / "Members".
        var title: String
        var isOn: Bool
        var id: String { role }
    }

    nonisolated struct Person: Sendable, Equatable, Identifiable {
        var id: String
        var name: String
        /// "Inactive" per chi non c'è più, altrimenti il ruolo ("Owner", "Member").
        var chip: String
        var isInactive: Bool
        var isOn: Bool
    }
}
