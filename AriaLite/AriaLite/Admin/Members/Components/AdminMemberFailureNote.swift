//
//  AdminMemberFailureNote.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una nota sottile con l'errore di una chiamata (accesso negato o altro), sopra il contenuto già a schermo.
//

import SwiftUI

struct AdminMemberFailureNote: View {
    let failure: AdminMembersFailure

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
