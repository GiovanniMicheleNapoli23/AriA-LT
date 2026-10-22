//
//  AdminMemoryFactFieldsCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una scheda del dettaglio fatta di righe "titolo → valore" (provenienza, affidabilità),
//  con un contenuto in più facoltativo sotto le righe.
//

import SwiftUI

struct AdminMemoryFactFieldsCard<Footer: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    let fields: [AdminAssetField]
    @ViewBuilder var footer: Footer

    var body: some View {
        AdminCard(title: title, systemImage: systemImage) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(fields) { field in
                    AdminFieldRow(field: field, showsDivider: field != fields.last)
                }
                footer
            }
        }
    }
}

extension AdminMemoryFactFieldsCard where Footer == EmptyView {
    init(title: LocalizedStringKey, systemImage: String, fields: [AdminAssetField]) {
        self.init(title: title, systemImage: systemImage, fields: fields) { EmptyView() }
    }
}
