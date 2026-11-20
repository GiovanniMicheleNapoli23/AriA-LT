//
//  AriaSettingsChoiceRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  Una scelta in una pagina delle impostazioni (aspetto, disponibilità, azienda, sito): il segno di spunta sulla
//  scelta attiva, la rotella mentre il server la salva.
//

import SwiftUI

struct AriaSettingsChoiceRow<Content: View>: View {
    let isSelected: Bool
    var isBusy = false
    let action: () -> Void
    @ViewBuilder var label: Content

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                label
                Spacer(minLength: 8)
                if isBusy {
                    ProgressView()
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.liteAccent)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .foregroundStyle(.primary)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
