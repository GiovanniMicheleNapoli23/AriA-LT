//
//  AdminDocumentChunkRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un chunk del testo estratto: numero, pagina, lunghezza e il testo (quattro righe, tocca per tutto).
//

import SwiftUI

struct AdminDocumentChunkRow: View {
    let chunk: AdminDocumentChunk
    @State private var isExpanded = false

    var body: some View {
        Button {
            withAnimation(.snappy) { isExpanded.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    if let ordinal = chunk.ordinal {
                        Text("#\(ordinal + 1)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(Color.liteAccent)
                    }
                    if let page = chunk.page {
                        Text("Page \(page)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    if let count = chunk.charCount {
                        Text("\(count) characters")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Text(chunk.text)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(isExpanded ? nil : 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .contentShape(Rectangle())
            .ariaGlass(in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(isExpanded ? "Shows less" : "Shows the full text"))
    }
}
