//
//  AriaTurnCreditNoteView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La nota sotto una risposta finita: una riga di testo piccolo con i crediti usati (e il livello di effort) e,
//  se ci sono, etichette grigie a capsula ("Extra credits", "Lighter model"). Tutto arriva già pronto dal view model.
//

import SwiftUI

struct AriaTurnCreditNoteView: View {
    let text: String
    let tags: [String]
    /// "Credits used by this reply: …", per VoiceOver.
    let accessibilityText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !tags.isEmpty { tagRow }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier("chat.creditNote")
    }

    /// Sulla stessa riga se ci stanno, altrimenti una sotto l'altra (testo grande).
    private var tagRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { chips }
            VStack(alignment: .leading, spacing: 6) { chips }
        }
    }

    private var chips: some View {
        ForEach(tags, id: \.self) { tag in
            Text(verbatim: tag)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.14), in: Capsule())
        }
    }
}
