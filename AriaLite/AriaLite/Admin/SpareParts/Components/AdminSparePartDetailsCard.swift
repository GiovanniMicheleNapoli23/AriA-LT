//
//  AdminSparePartDetailsCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I dati del ricambio (produttore, codice produttore, prezzo, ubicazione, fornitore…) come righe
//  etichetta-valore, poi gli asset compatibili e la descrizione. Le righe vuote non si mostrano.
//

import SwiftUI

struct AdminSparePartDetailsCard: View {
    let rows: [(label: String, value: String)]
    let assetTags: [String]
    let description: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Details", systemImage: "info.circle")
                .font(.headline)
                .padding(.bottom, 4)
            ForEach(rows, id: \.label) { row in
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: row.label).foregroundStyle(.secondary)
                    Spacer(minLength: 12)
                    Text(verbatim: row.value)
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                }
                .font(.subheadline)
                .padding(.vertical, 11)
                Divider()
            }
            if !assetTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Compatible assets").font(.subheadline).foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(assetTags, id: \.self) { tag in
                                Text(verbatim: tag)
                                    .font(.caption.monospaced().weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.liteAccent.opacity(0.08), in: Capsule())
                            }
                        }
                    }
                }
                .padding(.vertical, 11)
            }
            if let description {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Description").font(.subheadline).foregroundStyle(.secondary)
                    Text(verbatim: description)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 11)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}
