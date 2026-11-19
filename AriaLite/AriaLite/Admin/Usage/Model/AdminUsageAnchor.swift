//
//  AdminUsageAnchor.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Gli ancoraggi della pagina Usage verso cui `ScrollViewReader` scorre (l'azione "Set a spending limit" dell'avviso).
//

import Foundation

nonisolated enum AdminUsageAnchor: Hashable, Sendable {
    /// La scheda del tetto di spesa, dentro i controlli di fatturazione (contratto 5.1).
    case limitCard
}
