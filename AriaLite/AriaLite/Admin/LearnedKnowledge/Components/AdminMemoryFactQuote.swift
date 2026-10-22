//
//  AdminMemoryFactQuote.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un testo citato nel dettaglio (domanda, risposta di Aria, prova dai documenti): etichetta piccola
//  sopra e il testo con una barretta colorata a sinistra.
//

import SwiftUI

struct AdminMemoryFactQuote: View {
    let title: String
    let text: String
    var tint: Color = .liteAccent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 10)
                .overlay(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.5)).frame(width: 3)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
