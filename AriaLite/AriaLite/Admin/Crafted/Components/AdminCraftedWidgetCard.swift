//
//  AdminCraftedWidgetCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La card di un widget nella galleria: tipo, titolo, descrizione e il tool che lo genera.
//  I dati veri si vedono nel dettaglio (ogni card qui sarebbe una chiamata al server).
//

import SwiftUI

struct AdminCraftedWidgetCard: View {
    let widget: AdminCraftedWidget

    @ScaledMetric(relativeTo: .headline) private var iconSize: CGFloat = 34

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: AdminCraftedKind.systemImage(widget.kind))
                    .font(.headline)
                    .foregroundStyle(Color.liteAccent)
                    .frame(width: iconSize, height: iconSize)
                    .background(Color.liteAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
                Spacer(minLength: 8)
                Text(AdminCraftedKind.label(widget.kind))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
            }
            Text(widget.displayTitle)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if let description = widget.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            if !widget.toolName.isEmpty {
                Label(widget.toolName, systemImage: "function")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}
