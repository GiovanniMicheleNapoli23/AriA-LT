//
//  AdminMemberNoticeNote.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Una riga di avviso in cima alla scheda (esito della creazione, email non partita): arancio, non rosso.
//  Non è un errore: la persona esiste e l'azione è riuscita, solo in parte.
//

import SwiftUI

struct AdminMemberNoticeNote: View {
    let text: String
    var systemImage = "info.circle"

    var body: some View {
        Label {
            Text(verbatim: text)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.footnote)
        .foregroundStyle(.orange)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}
