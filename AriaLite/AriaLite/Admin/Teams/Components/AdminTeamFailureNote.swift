//
//  AdminTeamFailureNote.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Riga d'avviso nel dettaglio o nella bacheca: i dati sono quelli già a schermo, l'aggiornamento non è arrivato.
//

import SwiftUI

struct AdminTeamFailureNote: View {
    let message: String
    var isForbidden = false

    var body: some View {
        Label {
            Text(verbatim: message)
        } icon: {
            Image(systemName: isForbidden ? "lock" : "exclamationmark.triangle")
        }
        .font(.footnote)
        .foregroundStyle(.orange)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}
