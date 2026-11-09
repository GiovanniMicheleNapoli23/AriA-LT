//
//  AdminMarketplacePurchases.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Cosa ha comprato l'azienda, per id globale. Come sulla web (`pricing.ts`, chiave
//  `aria:marketplace:purchases:<company>` nel localStorage) non c'è ancora fatturazione né una rotta del
//  backend: l'acquisto resta su questo telefono, per azienda, e non arriva alla web né all'agente.
//

import Foundation

nonisolated struct AdminMarketplacePurchases {
    let companyId: String?
    var defaults: UserDefaults = .standard

    private var key: String { "aria.marketplace.purchases.\(companyId ?? "default")" }

    func load() -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    func save(_ ids: Set<String>) {
        defaults.set(ids.sorted(), forKey: key)
    }
}
