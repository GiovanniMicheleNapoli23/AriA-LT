//
//  AdminUsagePlaceholderCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il segnaposto di una scheda mentre i dati si leggono: righe sfocate sulla stessa superficie delle schede vere.
//  Nascosto a VoiceOver: la pagina dice una volta sola che sta caricando.
//

import SwiftUI

struct AdminUsagePlaceholderCard: View {
    /// Quante righe di testo finto, oltre al titolo.
    var lines = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: "Placeholder title").font(.headline)
            ForEach(0..<lines, id: \.self) { _ in
                Text(verbatim: "Placeholder text for a line of the card").font(.subheadline)
            }
        }
        .redacted(reason: .placeholder)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.liteSurface, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityHidden(true)
    }
}
