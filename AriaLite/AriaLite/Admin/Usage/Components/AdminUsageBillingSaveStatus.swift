//
//  AdminUsageBillingSaveStatus.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Come va l'ultimo salvataggio automatico di una scheda: "Saving…", "Saved" o "Not saved" con "Retry" (senza, quando prima va
//  corretto un valore). Ha un posto suo, così la scheda non si sposta quando il testo cambia.
//

import SwiftUI

struct AdminUsageBillingSaveStatus: View {
    let state: AdminUsageSaveState
    var canRetry = true
    let retry: () -> Void

    @ScaledMetric(relativeTo: .footnote) private var slotHeight: CGFloat = 24

    var body: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            switch state {
            case .idle:
                EmptyView()
            case .saving:
                ProgressView().controlSize(.small)
                label(Color.secondary)
            case .saved:
                Image(systemName: "checkmark").font(.footnote.weight(.semibold)).foregroundStyle(Color.liteSuccess)
                    .accessibilityHidden(true)
                label(Color.liteSuccess)
            case .error, .blocked:
                Image(systemName: "exclamationmark.circle.fill").font(.footnote).foregroundStyle(Color.liteDanger)
                    .accessibilityHidden(true)
                label(Color.primary)
                if state == .error, canRetry {
                    Button("Retry", action: retry)
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.liteAccent)
                        .frame(minHeight: 44)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: slotHeight, alignment: .trailing)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func label(_ style: some ShapeStyle) -> some View {
        if let text = state.text {
            Text(verbatim: text).font(.footnote).foregroundStyle(style)
        }
    }
}
