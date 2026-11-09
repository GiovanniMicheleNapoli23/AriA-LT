//
//  AdminExtractionHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'intestazione del dettaglio: titolo, codice e una riga di stato in testo semplice (stato, confidenza
//  dell'AI con il suo colore spento, ultimo aggiornamento). Il tipo è già nel titolo della barra.
//

import SwiftUI

struct AdminExtractionHeader: View {
    let item: AdminExtractionItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title)
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            if let code = item.code {
                Text(code)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            statusLine
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// In riga quando ci sta; con il testo grande una voce sotto l'altra, senza separatori.
    private var statusLine: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 6) { statusParts(separated: true) }
            VStack(alignment: .leading, spacing: 4) { statusParts(separated: false) }
        }
        .font(.footnote.weight(.medium))
    }

    @ViewBuilder
    private func statusParts(separated: Bool) -> some View {
        if let status = item.status {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Circle()
                    .fill(AdminExtractionTone.status(status))
                    .frame(width: 7, height: 7)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                Text(AdminAssetStatus.label(for: status))
            }
        }
        if let confidence = item.confidence {
            if separated && item.status != nil { separator }
            Text("AI confidence \(AdminExtractionTone.percent(confidence))")
                .foregroundStyle(AdminExtractionTone.confidence(confidence))
        }
        if let updated = item.updatedAt {
            if separated && (item.status != nil || item.confidence != nil) { separator }
            Text(updated.formatted(date: .abbreviated, time: .omitted))
                .foregroundStyle(.secondary)
        }
    }

    private var separator: some View {
        Text(verbatim: "·").foregroundStyle(.tertiary)
    }
}
