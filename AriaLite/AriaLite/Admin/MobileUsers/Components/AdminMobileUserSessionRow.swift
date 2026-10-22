//
//  AdminMobileUserSessionRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un telefono su cui l'operatore è entrato: nome del dispositivo, ultima attività e data di accesso,
//  con il pulsante per farlo uscire.
//

import SwiftUI

struct AdminMobileUserSessionRow: View {
    let title: String
    let line: String
    let onLogOut: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "iphone")
                .foregroundStyle(Color.liteAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                if !line.isEmpty {
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Button("Log out", systemImage: "rectangle.portrait.and.arrow.right", action: onLogOut)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}
