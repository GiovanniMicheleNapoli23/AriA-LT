//
//  AdminUsageBillingAlertBox.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il riquadro di una frase della scheda: un errore vero ("The limit was not saved…", "…could not be loaded") con la sua
//  icona, o una nota di avviso in ambra. Il rosso è solo degli errori veri; un dato che avvisa è ambra o grigio.
//

import SwiftUI

struct AdminUsageBillingAlertBox: View {
    nonisolated enum Kind: Sendable { case error, warning }

    let text: String
    var kind: Kind = .error

    private var tint: Color { kind == .error ? Color.liteDanger : Color.liteWarning }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: kind == .error ? "exclamationmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(verbatim: text)
                .font(.footnote)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
