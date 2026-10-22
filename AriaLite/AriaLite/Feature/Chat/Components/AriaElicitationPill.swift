//
//  AriaElicitationPill.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il pannello delle domande ridotto a pillola sopra il composer.
//

import SwiftUI

/// La domanda ancora aperta mentre si legge la chat o si scrive liberamente: un tocco la riapre.
struct AriaElicitationPill: View {
    let elicitation: AriaElicitation
    var isLearning = false
    var onExpand: () -> Void
    @ScaledMetric(relativeTo: .footnote) private var orbSide: CGFloat = 22

    var body: some View {
        Button(action: onExpand) {
            HStack(spacing: 10) {
                if isLearning {
                    AriaLearningIcon(size: 22)
                } else {
                    AriaOrb()
                        .frame(width: orbSide, height: orbSide)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(isLearning ? LocalizedStringKey("Real-time Learning") : "Aria is asking")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isLearning ? AriaLearningStyle.tint : .secondary)
                    Text(AriaMarkdown.inline(elicitation.allSteps.first?.question ?? elicitation.question))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text("Answer")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isLearning ? AriaLearningStyle.tint : Color.accentColor, in: Capsule())
            }
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
            .ariaGlass(in: Capsule(), interactive: true)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
