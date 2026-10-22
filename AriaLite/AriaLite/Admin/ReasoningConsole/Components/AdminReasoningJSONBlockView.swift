//
//  AdminReasoningJSONBlockView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un blocco di JSON della trace, chiuso di default: si apre per leggerlo in monospace (selezionabile),
//  tagliato se enorme; il testo intero si condivide o si copia dal foglio di condivisione.
//

import SwiftUI

struct AdminReasoningJSONBlockView: View {
    let block: AdminReasoningJSONBlock

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                Text(block.preview)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                HStack {
                    if block.isTruncated {
                        Text("Preview truncated")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    ShareLink(item: block.fullText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .font(.caption.weight(.semibold))
                }
            }
            .padding(.top, 6)
        } label: {
            HStack(alignment: .firstTextBaseline) {
                Text(block.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Text(block.size)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(.secondary)
    }
}
