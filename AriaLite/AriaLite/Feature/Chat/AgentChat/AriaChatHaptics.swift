//
//  AriaChatHaptics.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Gli haptic della conversazione si leggono dallo stato della chat, così valgono da qualunque
//  punto parta l'azione (composer, suggerimenti, aiuto sui task, domande guidate, card).
//

import SwiftUI

struct AriaChatHaptics: ViewModifier {
    let chat: AriaAgentChat

    /// Esito dell'ultima pausa decisa (approvazione o LOTO).
    private var outcome: AriaInterruptOutcome? {
        chat.messages.last(where: { $0.role == .assistant })?.interruptOutcome
    }

    func body(content: Content) -> some View {
        content
            // Turno nuovo: domanda e risposta in arrivo aggiunte insieme (lo storico caricato non conta).
            .sensoryFeedback(trigger: chat.messages.count) { old, new in
                new == old + 2 && chat.isStreaming ? .impact(weight: .light) : nil
            }
            // Aria ha finito e aspetta l'operatore: una decisione da prendere o una domanda.
            .sensoryFeedback(trigger: chat.isStreaming) { was, now in
                guard was, !now, chat.lastError == nil else { return nil }
                if chat.pendingInterrupt != nil { return .warning }
                if chat.activeElicitation != nil { return .impact(weight: .medium) }
                return nil
            }
            // La decisione sulla pausa: il LOTO confermato "pesa" più di un'approvazione.
            .sensoryFeedback(trigger: outcome) { _, new in
                guard chat.isStreaming, let new else { return nil }
                return switch new {
                case .approved, .edited: .success
                case .rejected: .impact(weight: .medium)
                case .lotoConfirmed: .impact(weight: .heavy)
                case .lotoDeclined: .warning
                }
            }
            .sensoryFeedback(.error, trigger: chat.lastError) { _, new in new != nil }
            .sensoryFeedback(.success, trigger: chat.notice) { _, new in new != nil }
    }
}

extension View {
    func ariaChatHaptics(_ chat: AriaAgentChat) -> some View {
        modifier(AriaChatHaptics(chat: chat))
    }
}
