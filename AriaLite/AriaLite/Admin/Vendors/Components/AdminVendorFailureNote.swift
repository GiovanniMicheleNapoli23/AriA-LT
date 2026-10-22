//
//  AdminVendorFailureNote.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Riga d'avviso nel dettaglio: la scheda è quella dell'elenco, l'aggiornamento non è arrivato.
//

import SwiftUI

struct AdminVendorFailureNote: View {
    let failure: AdminVendorsFailure

    var body: some View {
        Label {
            Text(verbatim: failure.message)
        } icon: {
            Image(systemName: failure.isForbidden ? "lock" : "exclamationmark.triangle")
        }
        .font(.footnote)
        .foregroundStyle(.orange)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}
