//
//  AdminSparePartStockCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La quantità a magazzino nel dettaglio: numero grande, scorta minima, avviso sotto scorta e la
//  correzione rapida (−, +, "Set quantity"). Per un articolo non a magazzino dice solo che non si segue.
//

import SwiftUI

struct AdminSparePartStockCard: View {
    let viewModel: AdminSparePartDetailViewModel

    private var tint: Color { viewModel.isDisplayedStockLow ? .red : Color.liteAccent }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label("Stock", systemImage: "shippingbox").font(.headline)
                Spacer()
                if viewModel.isStockPending {
                    ProgressView().controlSize(.small)
                }
            }
            if viewModel.canAdjustStock {
                quantityRow
                if viewModel.isDisplayedStockLow {
                    Label("Low stock", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                }
                Button("Set quantity", systemImage: "number") { viewModel.beginSettingQuantity() }
                    .font(.subheadline.weight(.semibold))
                    .ariaGlassButtonStyle()
            } else {
                Text("Non-stock item: the quantity isn't tracked.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    private var quantityRow: some View {
        HStack(spacing: 16) {
            stepButton("Remove one", systemImage: "minus", enabled: viewModel.canDecrement) { viewModel.decrement() }
            VStack(spacing: 2) {
                Text(verbatim: "\(viewModel.displayedStock)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .contentTransition(.numericText(value: Double(viewModel.displayedStock)))
                    .animation(.snappy, value: viewModel.displayedStock)
                if let caption = viewModel.stockCaption {
                    Text(verbatim: caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            stepButton("Add one", systemImage: "plus", enabled: true) { viewModel.increment() }
        }
        .sensoryFeedback(.selection, trigger: viewModel.displayedStock)
    }

    private func stepButton(_ title: LocalizedStringKey, systemImage: String, enabled: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 52, height: 52)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? Color.liteAccent : Color.secondary)
        .ariaGlass(in: Circle(), interactive: true)
        .disabled(!enabled)
        .accessibilityLabel(title)
    }
}
