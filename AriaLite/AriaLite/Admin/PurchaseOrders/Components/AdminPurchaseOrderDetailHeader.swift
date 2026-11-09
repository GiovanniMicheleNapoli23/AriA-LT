//
//  AdminPurchaseOrderDetailHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'intestazione del dettaglio: titolo, stato e le cifre chiave (totale, fornitore, consegna prevista) che vanno su una riga o si impilano. Con la consegna scaduta, un avviso.
//

import SwiftUI

struct AdminPurchaseOrderDetailHeader: View {
    let viewModel: AdminPurchaseOrderDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: viewModel.order.title)
                .font(.title3.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            AdminPurchaseOrderStatusBadge(status: viewModel.order.statusKind)
            figuresCard
            if let overdue = viewModel.overdueText {
                Label(overdue, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var figuresCard: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 24) { figures }
            VStack(alignment: .leading, spacing: 14) { figures }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var figures: some View {
        figure("Total") {
            Text(verbatim: viewModel.totalText)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.liteAccent)
        }
        figure("Vendor") {
            Text(verbatim: viewModel.vendorName)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
        }
        if let delivery = viewModel.expectedDeliveryText {
            figure("Expected delivery") {
                Text(verbatim: delivery)
                    .font(.headline)
                    .foregroundStyle(viewModel.isOverdue ? Color.orange : Color.primary)
            }
        }
    }

    private func figure(_ title: LocalizedStringKey, @ViewBuilder value: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            value()
        }
    }
}
