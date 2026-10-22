//
//  AdminVendorContactCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda contatti del dettaglio: email, telefono e sito toccabili, poi indirizzo. Le righe vuote non si mostrano.
//

import SwiftUI

struct AdminVendorContactCard: View {
    let items: [AdminVendorContactItem]

    @ScaledMetric(relativeTo: .body) private var iconWidth = 24.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Contact", systemImage: "person.crop.circle")
                .font(.headline)
                .padding(.bottom, 4)
            ForEach(items) { item in
                if let url = item.url {
                    Link(destination: url) { row(item, isLink: true) }
                } else {
                    row(item, isLink: false)
                }
                if item.id != items.last?.id { Divider() }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    private func row(_ item: AdminVendorContactItem, isLink: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: item.systemImage)
                .foregroundStyle(Color.liteAccent)
                .frame(width: iconWidth)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: item.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(verbatim: item.value)
                    .font(.subheadline)
                    .foregroundStyle(isLink ? Color.liteAccent : Color.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if isLink {
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}
