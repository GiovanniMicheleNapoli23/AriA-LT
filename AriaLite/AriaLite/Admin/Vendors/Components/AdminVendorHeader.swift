//
//  AdminVendorHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'intestazione del dettaglio: nome, ragione sociale, tipo e rating.
//

import SwiftUI

struct AdminVendorHeader: View {
    let vendor: AdminVendor
    let rating: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: vendor.title)
                .font(.title3.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            if let company = vendor.distinctCompanyName {
                Text(verbatim: company)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            HStack(spacing: 10) {
                if let type = vendor.typeLabel { AdminVendorTypeBadge(label: type) }
                if let rating { AdminVendorRatingView(value: rating) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
