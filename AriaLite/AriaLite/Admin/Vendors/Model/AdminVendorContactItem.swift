//
//  AdminVendorContactItem.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una riga della scheda contatti del dettaglio: icona, etichetta, valore e, se si può toccare,
//  il link da aprire (mailto, tel, sito).
//

import Foundation

nonisolated struct AdminVendorContactItem: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let value: String
    let systemImage: String
    var url: URL?
}
