//
//  AriaBackend+UsageEntry.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La voce "Usage" della sidebar secondo la config dei consumi (contratto Usage §2): si vede mentre la config non ha
//  risposto o è fallita (la pagina offre "Riprova"), sparisce quando dice che i clienti non vedono i consumi o quando
//  il backend non ha le rotte per questa sessione.
//

import Foundation

extension AriaBackend {
    var usageEntryVisible: Bool {
        AdminUsageAccess.entry(config: usage.config, configPhase: usage.configPhase,
                               isUnavailable: usage.isUnavailable, rights: rights) != .hidden
    }
}
