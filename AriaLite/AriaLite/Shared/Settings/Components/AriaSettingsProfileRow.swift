//
//  AriaSettingsProfileRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  La prima riga delle impostazioni: avatar, nome ed email. Apre la pagina dell'account.
//

import SwiftUI

struct AriaSettingsProfileRow: View {
    let initials: String
    let name: String
    let email: String?

    @ScaledMetric(relativeTo: .body) private var avatarSide: CGFloat = 44

    var body: some View {
        HStack(spacing: 12) {
            AriaSettingsAvatar(initials: initials, side: avatarSide)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name)
                    .font(.headline)
                if let email {
                    Text(verbatim: email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
