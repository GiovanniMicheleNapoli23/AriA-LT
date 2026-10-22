//
//  AdminLLMUsageViewModel+Sessions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo Stop di una sessione attiva: quando si può e la conferma. La chiamata (`confirmStop`) sta nel file
//  principale, perché scrive proprietà `private(set)`.
//

import Foundation

extension AdminLLMUsageViewModel {
    /// Stop è disponibile solo per le sessioni ancora attive e una alla volta.
    func canStop(_ session: AdminLLMUsageSession) -> Bool {
        session.isActive && stoppingSessionId == nil
    }

    /// Apre la conferma: nessuna chiamata finché non si conferma.
    func requestStop(_ session: AdminLLMUsageSession) {
        guard canStop(session) else { return }
        sessionToStop = session
    }
}
