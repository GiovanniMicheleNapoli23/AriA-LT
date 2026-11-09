//
//  AdminMobileUserStepRowData.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una riga della schermata dei passi: il passo (se la procedura è arrivata) e il suo report (se c'è).
//

import Foundation

nonisolated struct AdminMobileUserStepRowData: Sendable, Identifiable, Hashable {
    let id: String
    let number: Int?
    let text: String?
    let report: AdminMobileUserStepReport?
}
