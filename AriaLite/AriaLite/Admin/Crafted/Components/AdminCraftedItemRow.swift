//
//  AdminCraftedItemRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  La riga della libreria Crafted: icona del tipo (o rotella mentre Aria lavora), titolo su due righe,
//  data, tipo o stato (o verdetto con il suo pallino) e il segno "modificato".
//

import SwiftUI

struct AdminCraftedItemRow: View {
    let title: String
    let info: AdminCraftedRowInfo

    @ScaledMetric(relativeTo: .headline) private var iconSize: CGFloat = 34

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) { meta }
                    VStack(alignment: .leading, spacing: 2) { meta }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private var icon: some View {
        ZStack {
            if info.isGenerating {
                ProgressView()
            } else {
                Image(systemName: info.systemImage)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: iconSize, height: iconSize)
        .background(Color.secondary.opacity(0.12), in: Circle())
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var meta: some View {
        Text(info.dateText)
        if let detail = info.detail {
            Text(verbatim: "·").foregroundStyle(.tertiary)
            HStack(spacing: 5) {
                if info.showsVerdictDot {
                    Circle()
                        .fill(info.detailTint ?? .secondary)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                }
                Text(detail)
                    .foregroundStyle(info.isError ? Color.red : (info.detailTint ?? Color.secondary))
            }
        }
        if let edited = info.edited {
            Text(verbatim: "·").foregroundStyle(.tertiary)
            Text(edited).fontWeight(.medium)
        }
    }
}
