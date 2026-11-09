//
//  AdminCraftedAriaThread.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Cosa si sono detti operatore e Aria in questa modifica: le istruzioni date, e per ognuna la riga di
//  Aria su cosa ha fatto — o il vero motivo per cui non ci è riuscita.
//

import SwiftUI

struct AdminCraftedAriaThread: View {
    let lines: [AdminCraftedAriaEditor.Line]

    @ScaledMetric(relativeTo: .callout) private var orbSide: CGFloat = 22

    var body: some View {
        ForEach(lines) { line in
            if line.isAria {
                HStack(alignment: .top, spacing: 10) {
                    AriaOrb(isAnimating: false).frame(width: orbSide, height: orbSide)
                    Text(line.text).font(.callout)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            } else {
                Text(line.text)
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.liteAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    // Una nuvoletta, non una riga intera: le istruzioni si distinguono dalle risposte anche a colpo d'occhio.
                    .padding(.leading, 48)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

/// Tre istruzioni di partenza, come chip che vanno a capo: un tocco le manda.
struct AdminCraftedAriaSuggestions: View {
    let isEnabled: Bool
    let pick: (String) -> Void

    var body: some View {
        AdminMarketplaceFlowLayout(spacing: 8) {
            suggestion(String(localized: "Make it more concise"), icon: "text.badge.minus")
            suggestion(String(localized: "Make the tone more formal"), icon: "briefcase")
            suggestion(String(localized: "Fix typos and grammar"), icon: "textformat.abc.dottedunderline")
        }
        .disabled(!isEnabled)
    }

    private func suggestion(_ text: String, icon: String) -> some View {
        Button { pick(text) } label: {
            Label {
                Text(text)
            } icon: {
                Image(systemName: icon).foregroundStyle(Color.liteAccent)
            }
            .font(.subheadline)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.fill.tertiary, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
