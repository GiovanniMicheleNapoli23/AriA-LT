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
    /// Il pulsante c'è per le sessioni ancora attive che il ruolo può fermare: la propria basta la sezione, quella
    /// di un altro vuole l'azione `stop_session`.
    func showsStop(_ session: AdminLLMUsageSession) -> Bool {
        guard session.isActive else { return false }
        if let own = backend.mobileAccount?.id, session.userId == own { return true }
        return backend.rights.can(.stopSession, in: .llmUsage)
    }

    /// Stop è disponibile solo per le sessioni che lo mostrano e una alla volta.
    func canStop(_ session: AdminLLMUsageSession) -> Bool {
        showsStop(session) && stoppingSessionId == nil
    }

    /// Apre la conferma: nessuna chiamata finché non si conferma.
    func requestStop(_ session: AdminLLMUsageSession) {
        guard canStop(session) else { return }
        sessionToStop = session
    }
}
