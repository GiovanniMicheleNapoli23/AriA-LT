//
//  AriaSettingsSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  Un gruppo del profilo: titolo piccolo sopra e le righe in una scheda sola, separate da una linea.
//

import SwiftUI

struct AriaSettingsSection<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                Group(subviews: content) { rows in
                    ForEach(rows) { row in
                        row
                        if row.id != rows.last?.id { Divider().padding(.leading, 54) }
                    }
                }
            }
            .background(Color.liteSurface, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}
