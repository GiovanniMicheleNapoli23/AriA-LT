//
//  AdminPurchaseOrderDetailFailureNote.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'avviso in cima al dettaglio quando l'aggiornamento dal server non è arrivato: la scheda mostrata è quella dell'elenco.
//

import SwiftUI

struct AdminPurchaseOrderDetailFailureNote: View {
    let failure: AdminPurchaseOrdersFailure

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
