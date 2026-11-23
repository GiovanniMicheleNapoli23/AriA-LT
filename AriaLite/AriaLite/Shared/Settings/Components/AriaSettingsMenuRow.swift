//
//  AriaSettingsMenuRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/11/26.
//
//  Una riga delle impostazioni che apre un menu di scelte (azienda, sito). Come un Picker a menu, ma il valore
//  scelto resta su una riga e si tronca con "…" quando il nome è troppo lungo, senza schiacciare il titolo.
//

import SwiftUI

struct AriaSettingsMenuRow<Title: View, Choices: View>: View {
    let value: String?
    @ViewBuilder var title: Title
    @ViewBuilder var choices: Choices

    var body: some View {
        Menu {
            choices
        } label: {
            HStack(spacing: 8) {
                title
                    .layoutPriority(1)
                Spacer(minLength: 12)
                if let value {
                    Text(verbatim: value)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .foregroundStyle(.primary)
    }
}
