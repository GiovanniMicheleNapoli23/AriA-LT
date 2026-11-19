//
//  AdminUsageMemberLimitSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda "Spending limit" di un membro (contratto 3.9), al posto dei controlli di fatturazione: l'importo, lo stato e
//  le note. Si legge tutta di seguito; la nota in fondo alla pagina ("Amounts in EUR…") è a parte.
//

import SwiftUI

struct AdminUsageMemberLimitSection: View {
    let limit: AdminUsageMemberLimit

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        AdminUsageCardFrame(title: Text(verbatim: limit.title)) {
            VStack(alignment: .leading, spacing: 8) {
                header
                if let credits = limit.creditsEquivalent { footnote(credits) }
                if let warned = limit.warnedNote { footnote(warned) }
                if let reached = limit.reachedNote { footnote(reached) }
                footnote(limit.managedNote)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var header: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            Text(verbatim: limit.amount).font(.title2.weight(.semibold).monospacedDigit())
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Text(verbatim: limit.chip)
                .font(.caption.weight(.semibold))
                .foregroundStyle(limit.isReached ? Color.secondary : Color.liteAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background((limit.isReached ? Color.secondary : Color.liteAccent).opacity(0.14), in: Capsule())
        }
    }

    private func footnote(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
