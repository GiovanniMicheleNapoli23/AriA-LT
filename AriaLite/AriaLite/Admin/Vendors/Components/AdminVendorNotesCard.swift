//
//  AdminVendorNotesCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le note del fornitore e, sotto, le date di creazione e di ultimo aggiornamento.
//

import SwiftUI

struct AdminVendorNotesCard: View {
    let notes: String?
    let dateRows: [(label: String, value: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let notes {
                Label("Notes", systemImage: "note.text")
                    .font(.headline)
                Text(verbatim: notes)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                if !dateRows.isEmpty { Divider() }
            }
            ForEach(dateRows, id: \.label) { row in
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: row.label).foregroundStyle(.secondary)
                    Spacer(minLength: 12)
                    Text(verbatim: row.value)
                        .multilineTextAlignment(.trailing)
                }
                .font(.footnote)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}
