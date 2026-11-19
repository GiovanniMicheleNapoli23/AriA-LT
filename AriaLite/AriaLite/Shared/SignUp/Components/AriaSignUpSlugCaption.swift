//
//  AriaSignUpSlugCaption.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La riga sotto l'indirizzo del workspace, con le parole della web: "disponibile", "non disponibile", oppure
//  "Verifica non riuscita. Riprova" (che non blocca: la creazione ricontrolla).
//

import SwiftUI

struct AriaSignUpSlugCaption: View {
    let model: AriaSignUpViewModel

    var body: some View {
        Group {
            switch model.slugState {
            case .available:
                address(Text("available").foregroundStyle(Color.liteAccent))
            case .taken:
                address(Text("taken").foregroundStyle(.red))
            case .failed:
                HStack(spacing: 6) {
                    Text("Couldn't check it.")
                        .foregroundStyle(.secondary)
                    Button("Try again") { model.retrySlugCheck() }
                        .foregroundStyle(Color.liteAccent)
                        .fontWeight(.medium)
                }
            case .checking:
                Text("Checking…")
                    .foregroundStyle(.tertiary)
            case .idle:
                Text("At least 2 letters or numbers.")
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.caption)
    }

    /// "aria.app/acme · disponibile": l'indirizzo per intero, poi l'esito con la parola della web.
    private func address(_ outcome: some View) -> some View {
        HStack(spacing: 4) {
            Text(verbatim: "aria.app/\(model.normalizedSlug) ·")
                .foregroundStyle(.secondary)
            outcome
        }
        .accessibilityElement(children: .combine)
    }
}
