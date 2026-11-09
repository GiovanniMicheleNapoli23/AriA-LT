//
//  AdminPurchaseOrderRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Scheda di un ordine nella lista: titolo e stato in alto, fornitore, date (consegna in ritardo in rosso),
//  poi totale e numero di righe. Con testo molto grande le righe vanno in colonna.
//

import SwiftUI

struct AdminPurchaseOrderRow: View {
    let info: AdminPurchaseOrderRowInfo

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let isAX = dynamicTypeSize.isAccessibilitySize
        let line = isAX
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        VStack(alignment: .leading, spacing: 8) {
            line {
                Text(verbatim: info.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(isAX ? nil : 2)
                if !isAX { Spacer(minLength: 8) }
                AdminPurchaseOrderStatusBadge(status: info.status)
            }
            if let vendorName = info.vendorName {
                Label { Text(verbatim: vendorName) } icon: { Image(systemName: "storefront") }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(isAX ? nil : 1)
            }
            dates
            line {
                Text(verbatim: info.totalText)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.primary)
                if !isAX { Spacer(minLength: 8) }
                Text(verbatim: info.linesText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            if info.isOverdue {
                RoundedRectangle(cornerRadius: 16).strokeBorder(Color.red.opacity(0.35), lineWidth: 1)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }

    /// Le date affiancate se ci stanno, altrimenti una sotto l'altra.
    @ViewBuilder
    private var dates: some View {
        if info.orderDateText != nil || info.expectedText != nil {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { dateLabels.fixedSize(horizontal: true, vertical: false) }
                VStack(alignment: .leading, spacing: 4) { dateLabels }
            }
        }
    }

    @ViewBuilder
    private var dateLabels: some View {
        if let text = info.orderDateText {
            Label { Text(verbatim: text) } icon: { Image(systemName: "calendar") }
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        if let text = info.expectedText {
            Label { Text(verbatim: text) } icon: {
                Image(systemName: info.isOverdue ? "exclamationmark.triangle.fill" : "shippingbox")
            }
            .font(.caption.weight(info.isOverdue ? .semibold : .regular))
            .foregroundStyle(info.isOverdue ? Color.red : Color.secondary)
        }
    }
}
