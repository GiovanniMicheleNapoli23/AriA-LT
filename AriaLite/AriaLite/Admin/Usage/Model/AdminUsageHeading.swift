//
//  AdminUsageHeading.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  L'intestazione della pagina Usage e il selettore del ciclo (contratto 3.2), già scritti.
//

import Foundation

nonisolated struct AdminUsageHeading: Sendable, Equatable {
    /// Il piano ("Professional"); "Free Demo" sul ciclo corrente di una prova; vuoto se il piano non si sa.
    var plan: String
    /// "November 2026 cycle".
    var cycle: String
    /// "Professional · November 2026 cycle" (solo "November 2026 cycle" senza piano).
    var title: String
    /// La riga dei fatti: le date, l'azzeramento (o "Closed (UTC)") e, sul ciclo corrente, i giorni che restano.
    var facts: [String]
}

/// Una voce del selettore "Billing cycle": un mese, il più recente per primo.
nonisolated struct AdminUsageCycleOption: Sendable, Equatable, Identifiable {
    var cycle: AriaUsageDashboard.Cycle
    /// "November 2026", oppure "November 2026 · current cycle".
    var title: String
    /// È il ciclo in corso: sceglierlo torna al ciclo corrente.
    var isCurrent: Bool

    var id: String { cycle.start }
}
