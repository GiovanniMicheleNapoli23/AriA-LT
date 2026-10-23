//
//  AdminCraftedReportEditHint.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Il suggerimento sopra la pagina mentre si modifica: si tocca un paragrafo o una cella, e salvando
//  nasce la versione successiva (il rapporto scritto dal backend resta sempre).
//

import SwiftUI

struct AdminCraftedReportEditHint: View {
    let nextNumber: Int

    var body: some View {
        AriaCard {
            HStack(spacing: 6) {
                Image(systemName: "pencil")
                Text("Editing")
            }
            .font(.subheadline.weight(.semibold))
            Text("Tap a paragraph or a table cell on the page to change it. Saving makes version \(nextNumber): the report as written always stays.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
