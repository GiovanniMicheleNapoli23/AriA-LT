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

    var body: some View {
        ForEach(lines) { line in
            if line.isAria {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "sparkles").foregroundStyle(Color.liteAccent)
                    Text(line.text).font(.callout)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            } else {
                Text(line.text)
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.liteAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

/// Tre istruzioni di partenza: un tocco le mette nel campo.
struct AdminCraftedAriaSuggestions: View {
    let pick: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            suggestion(String(localized: "Make it more concise"))
            suggestion(String(localized: "Make the tone more formal"))
            suggestion(String(localized: "Fix typos and grammar"))
        }
    }

    private func suggestion(_ text: String) -> some View {
        Button { pick(text) } label: {
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
