//
//  AriaSettingsRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/10/26.
//
//  Una riga del profilo: simbolo, titolo e valore a destra. Se non ci stanno su una riga
//  (testo grande, schermo stretto) il valore va sotto il titolo.
//

import SwiftUI

struct AriaSettingsRow<Value: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    var showsChevron = false
    @ViewBuilder var value: Value

    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 26

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                icon
                Text(title).font(.body.weight(.medium)).fixedSize()
                Spacer(minLength: 8)
                value.fixedSize()
                chevron
            }
            HStack(spacing: 12) {
                icon
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.body.weight(.medium))
                    value
                }
                Spacer(minLength: 8)
                chevron
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    private var icon: some View {
        Image(systemName: systemImage)
            .font(.body.weight(.medium))
            .foregroundStyle(Color.liteAccent)
            .frame(width: iconWidth)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var chevron: some View {
        if showsChevron {
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }
}
