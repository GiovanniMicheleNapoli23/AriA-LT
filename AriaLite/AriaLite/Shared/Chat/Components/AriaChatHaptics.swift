//
//  AriaChatHaptics.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Gli haptic della conversazione si leggono dallo stato della chat, così valgono da qualunque
//  punto parta l'azione (composer, suggerimenti, aiuto sui task, domande guidate, card).
//  Quale haptic e quando lo decide AriaAgentChatViewModel.
//

import SwiftUI

struct AriaChatHaptics: ViewModifier {
    let model: AriaAgentChatViewModel

    func body(content: Content) -> some View {
        content
            .sensoryFeedback(trigger: model.messageCount) { old, new in
                model.feedbackForMessages(from: old, to: new)
            }
            .sensoryFeedback(trigger: model.isStreaming) { was, now in
                model.feedbackForStreaming(was: was, now: now)
            }
            .sensoryFeedback(trigger: model.lastInterruptOutcome) { _, new in
                model.feedback(for: new)
            }
            .sensoryFeedback(.error, trigger: model.turnError) { _, new in new != nil }
            .sensoryFeedback(.success, trigger: model.notice) { _, new in new != nil }
    }
}

extension View {
    func ariaChatHaptics(_ model: AriaAgentChatViewModel) -> some View {
        modifier(AriaChatHaptics(model: model))
    }
}
