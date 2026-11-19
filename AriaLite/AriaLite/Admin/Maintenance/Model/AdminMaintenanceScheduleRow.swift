//
//  AdminMaintenanceScheduleRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 11/11/26.
//
//  Una riga della programmazione nell'intestazione del dettaglio: "Next due  12 dic · tra 4 settimane".
//

import Foundation

nonisolated struct AdminMaintenanceScheduleRow: Identifiable, Hashable, Sendable {
    let title: String
    let value: String
    /// Solo sulla prossima scadenza: scaduta o vicina, il valore prende il colore della pastiglia.
    var dueState: AdminMaintenanceDueState?

    var id: String { title }
}
