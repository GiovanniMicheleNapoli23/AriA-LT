//
//  AdminPurchaseOrderDetailInfoCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I dati dell'ordine (date, stabilimento, approvazione, indirizzo, note) come righe etichetta-valore; indirizzo e note vanno a capo sotto l'etichetta. Le righe vuote non si mostrano.
//

import SwiftUI

struct AdminPurchaseOrderDetailInfoCard: View {
    let rows: [AdminPurchaseOrderDetailInfoRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Details", systemImage: "info.circle")
                .font(.headline)
                .padding(.bottom, 4)
            if rows.isEmpty {
                Text("No details yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 11)
            }
            ForEach(rows) { row in
                Group {
                    if row.isBlock { block(row) } else { inline(row) }
                }
                .font(.subheadline)
                .padding(.vertical, 11)
                Divider()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    private func inline(_ row: AdminPurchaseOrderDetailInfoRow) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: row.label).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(verbatim: row.value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }

    private func block(_ row: AdminPurchaseOrderDetailInfoRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: row.label).foregroundStyle(.secondary)
            Text(verbatim: row.value)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
