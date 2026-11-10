//
//  AdminAlarmFact.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Un fatto dell'intestazione del dettaglio (asset, zona, categoria, pagina HMI): etichetta, valore e icona.
//

import Foundation

nonisolated struct AdminAlarmFact: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let value: String
    let systemImage: String
}
