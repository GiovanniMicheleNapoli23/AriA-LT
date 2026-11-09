//
//  AdminPurchaseOrderDetailLinesCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le righe dell'ordine con il subtotale e, se l'ordine è modificabile, "Add line" per aggiungerne una. Togliere una riga chiede conferma al view model.
//

import SwiftUI

struct AdminPurchaseOrderDetailLinesCard: View {
    let viewModel: AdminPurchaseOrderDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if viewModel.lineDisplays.isEmpty {
                Text("No lines yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 11)
            }
            ForEach(viewModel.lineDisplays) { line in
                AdminPurchaseOrderLineRow(
                    line: line,
                    canRemove: viewModel.canEditLines,
                    isRemoving: viewModel.isRunning(.removeLine(line.id)),
                    isDisabled: viewModel.isBusy
                ) { viewModel.askToRemove(lineId: line.id) }
                Divider()
            }
            if let subtotal = viewModel.subtotalText {
                HStack {
                    Text("Subtotal").foregroundStyle(.secondary)
                    Spacer(minLength: 12)
                    Text(verbatim: subtotal).fontWeight(.semibold).monospacedDigit()
                }
                .font(.subheadline)
                .padding(.top, 11)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack { title; Spacer(minLength: 8); addButton }
            VStack(alignment: .leading, spacing: 8) { title; addButton }
        }
        .padding(.bottom, 4)
    }

    private var title: some View {
        Label {
            Text("Lines") + Text(verbatim: " (\(viewModel.lineCount))").foregroundStyle(.secondary)
        } icon: {
            Image(systemName: "list.bullet")
        }
        .font(.headline)
    }

    @ViewBuilder
    private var addButton: some View {
        if viewModel.canEditLines {
            Button("Add line", systemImage: "plus") { viewModel.startAddingLine() }
                .font(.subheadline.weight(.semibold))
                .ariaGlassButtonStyle()
                .disabled(viewModel.isBusy)
        }
    }
}
