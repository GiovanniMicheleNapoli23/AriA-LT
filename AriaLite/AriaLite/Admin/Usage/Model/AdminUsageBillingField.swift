//
//  AdminUsageBillingField.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Quale campo di testo dei controlli di fatturazione ha il fuoco: il limite di spesa o la soglia di un avviso. Il fuoco lo
//  tiene `AdminUsageBillingControls`, così c'è un solo "Done" sulla tastiera e la soglia si salva quando si lascia.
//

import Foundation

nonisolated enum AdminUsageBillingField: Hashable, Sendable {
    case limit
    case threshold(AriaNoticeKey)
}
