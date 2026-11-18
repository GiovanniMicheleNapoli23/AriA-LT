//
//  AriaSignUpSavedCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Quello che il server ha già (l'azienda, lo stabilimento), in sola lettura: tornando indietro si vede ma non si
//  cambia più. Come la scheda "Il tuo workspace è già stato creato" della web.
//

import SwiftUI

struct AriaSignUpSavedCard: View {
    let icon: String
    let title: String
    let detail: String?
    let note: LocalizedStringResource

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.liteAccent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: title)
                    .font(.headline)
                    .foregroundStyle(Color.liteText)
                if let detail {
                    Text(verbatim: detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.liteAccent)
                .accessibilityHidden(true)
        }
        .padding(16)
        .ariaSignUpCard()
        .accessibilityElement(children: .combine)
    }
}
