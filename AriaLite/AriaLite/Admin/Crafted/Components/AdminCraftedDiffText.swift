//
//  AdminCraftedDiffText.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Un testo letto contro un altro: le parole aggiunte su verde, quelle tolte su rosso e barrate, il resto
//  com'era. Un solo Text da un AttributedString, così a capo come un testo normale. Vale per qualunque
//  elenco di segmenti (artifact e report).
//

import SwiftUI

struct AdminCraftedDiffText: View {
    let segments: [AdminCraftedTextDiff.Segment]

    var body: some View {
        Text(Self.attributed(segments))
            .font(.callout)
            .lineSpacing(4)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    static func attributed(_ segments: [AdminCraftedTextDiff.Segment]) -> AttributedString {
        var result = AttributedString()
        for segment in segments {
            var piece = AttributedString(segment.text)
            switch segment.type {
            case .added:
                piece.backgroundColor = Color.green.opacity(0.28)
            case .removed:
                piece.backgroundColor = Color.red.opacity(0.24)
                piece.strikethroughStyle = .single
            case .same:
                break
            }
            result.append(piece)
        }
        return result
    }
}

/// Il segno che spiega i colori: aggiunto e tolto, come nella barra del confronto.
struct AdminCraftedDiffLegend: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("added")
                .padding(.horizontal, 6)
                .background(Color.green.opacity(0.28), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            Text("removed")
                .strikethrough()
                .padding(.horizontal, 6)
                .background(Color.red.opacity(0.24), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .font(.caption)
    }
}
