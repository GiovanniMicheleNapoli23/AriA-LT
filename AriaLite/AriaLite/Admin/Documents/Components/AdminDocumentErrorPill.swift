//
//  AdminDocumentErrorPill.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Contenuto già a schermo ma l'ultimo aggiornamento è fallito: una riga sottile con il motivo e "Retry".
//

import SwiftUI

struct AdminDocumentErrorPill: View {
    let message: String
    var isDisabled = false
    let retry: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Button("Retry", action: retry)
                .font(.footnote.weight(.semibold))
                .disabled(isDisabled)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .ariaGlass(in: Capsule())
        .frame(maxWidth: .infinity)
    }
}
