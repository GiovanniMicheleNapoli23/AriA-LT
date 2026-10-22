//
//  AdminDocumentRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una riga della libreria: icona del tipo, nome, tipo/pagine/peso, data e stato complessivo.
//

import SwiftUI

struct AdminDocumentRow: View {
    let document: AdminDocument

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Testo enorme: l'icona ruberebbe spazio al nome.
            if !dynamicTypeSize.isAccessibilitySize {
                AdminDocumentFileIcon(fileName: document.fileName, mimeType: document.mimeType)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(document.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                if !document.summaryLine.isEmpty {
                    Text(document.summaryLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) { badge; date }
                    VStack(alignment: .leading, spacing: 4) { badge; date }
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    private var badge: some View {
        AdminDocumentStatusBadge(group: document.statusGroup)
            .symbolEffect(.rotate, isActive: document.statusGroup == .processing)
    }

    @ViewBuilder
    private var date: some View {
        if let created = document.createdAt {
            Text(created.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}
