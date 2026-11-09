//
//  AdminTeamDistributionRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una riga già pronta di una distribuzione (stato, priorità o categoria): etichetta, colore e conteggio.
//

import SwiftUI

struct AdminTeamDistributionRow: Identifiable, Hashable {
    let id: String
    let label: String
    let tint: Color
    let count: Int
}
