//
//  AdminMarketplaceAddsCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  La scheda 'cosa aggiunge' (il titolo cambia col tipo): le frasi del catalogo con una spunta.
//

import SwiftUI

struct AdminMarketplaceAddsCard: View {
    let title: String
    let lines: [String]

    var body: some View {
        AdminMarketplaceDetailCard(title: Text(verbatim: title), systemImage: "checklist") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "checkmark")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(verbatim: line)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}
