//
//  AdminVendorRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Scheda di un fornitore nella lista: nome e tipo in alto, ragione sociale, poi città e rating.
//

import SwiftUI

struct AdminVendorRow: View {
    let vendor: AdminVendor

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Testo molto grande: le righe vanno in colonna invece di spezzarsi a metà parola.
        let isAX = dynamicTypeSize.isAccessibilitySize
        let line = isAX
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        VStack(alignment: .leading, spacing: 8) {
            line {
                Text(verbatim: vendor.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(isAX ? nil : 2)
                if !isAX { Spacer(minLength: 8) }
                if let type = vendor.typeLabel { AdminVendorTypeBadge(label: type) }
            }
            if let company = vendor.distinctCompanyName {
                Text(verbatim: company)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(isAX ? nil : 1)
            }
            line {
                if let place = vendor.cityAndCountry {
                    Label(place, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if !isAX { Spacer(minLength: 8) }
                if let rating = vendor.clampedRating { AdminVendorRatingView(value: rating, isCompact: true) }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}
