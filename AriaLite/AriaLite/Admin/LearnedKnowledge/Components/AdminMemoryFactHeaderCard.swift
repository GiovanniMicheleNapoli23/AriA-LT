//
//  AdminMemoryFactHeaderCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La testa del dettaglio: stato, tipo e provenienza, il testo del fatto (tradotto, con il pulsante
//  per vedere l'originale) e il contesto in cui vale.
//

import SwiftUI

struct AdminMemoryFactHeaderCard: View {
    let fact: AdminMemoryFact
    let text: String
    let summary: String
    /// C'è una traduzione: si offre il passaggio all'originale e ritorno.
    let isTranslated: Bool
    @Binding var showsOriginal: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let status = fact.status { AdminMemoryFactStatusBadge(status: status) }
            Text(text)
                .font(.title3.weight(.semibold))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            if let context = fact.context {
                Label {
                    Text(context).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "scope")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            if !summary.isEmpty {
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if isTranslated {
                Button {
                    withAnimation(.snappy) { showsOriginal.toggle() }
                } label: {
                    Label(showsOriginal ? "Show translation" : "Show original", systemImage: "translate")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .tint(Color.liteAccent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}
