//
//  AriaAccessPausedBanner.swift
//  AriaLite
//
//  Created by Giovanni Michele on 03/11/26.
//
//  "Il tuo accesso è in pausa": il membro non ha un ruolo, o l'admin lo ha messo in pausa. Restano la chat e le
//  schermate sempre disponibili. Non è un errore, quindi non è rosso.
//

import SwiftUI

struct AriaAccessPausedBanner: View {
    @ScaledMetric(relativeTo: .subheadline) private var iconSide: CGFloat = 30

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "pause.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: iconSide, height: iconSide)
                .background(Color.secondary.opacity(0.12), in: Circle())
            Text("Your access is paused. Ask your admin.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.liteText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    AriaAccessPausedBanner()
        .padding()
}
