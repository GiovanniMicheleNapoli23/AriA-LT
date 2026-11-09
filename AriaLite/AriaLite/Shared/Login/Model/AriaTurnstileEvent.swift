//
//  AriaTurnstileEvent.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Cosa racconta il captcha Cloudflare Turnstile del magic link della web (AriaTurnstileView).
//

import Foundation

nonisolated enum AriaTurnstileEvent: Sendable, Equatable {
    /// Token pronto: vale 5 minuti, una volta sola.
    case token(String)
    /// Il token è scaduto: Turnstile ne conia un altro da solo.
    case expired
    /// Il widget non è riuscito (rete, chiave, dominio): il magic link della web non si può chiedere.
    case failed
    /// Turnstile vuole un tocco dell'utente (`true`) o l'ha avuto (`false`): il riquadro si mostra solo allora.
    case needsInteraction(Bool)
}
