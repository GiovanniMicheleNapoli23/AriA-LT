//
//  AdminReportSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il guscio di una parte della pagina Reports: titolo e, secondo lo stato, rotella, errore con Riprova,
//  messaggio di vuoto o il contenuto. Ogni parte ha il suo stato e non rompe le altre.
//

import SwiftUI

struct AdminReportSection<Value: Sendable, Content: View>: View {
    let title: LocalizedStringKey
    let load: AdminReportLoad<Value>
    /// Il testo quando i dati sono arrivati ma non c'è niente da mostrare.
    let emptyText: String
    let isEmpty: (Value) -> Bool
    let retry: () async -> Void
    @ViewBuilder let content: (Value) -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            if let value = load.value {
                if let message = load.errorMessage {
                    failure(message)
                }
                if isEmpty(value) {
                    AdminSectionNotice(text: emptyText)
                } else {
                    content(value)
                }
            } else if let message = load.errorMessage {
                failure(message)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
        }
    }

    /// Il motivo e il tasto per riprovare, sul posto.
    private func failure(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            AdminSectionNotice(text: message, isError: true)
            Button {
                Task { await retry() }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .ariaGlassButtonStyle()
            .disabled(load.isLoading)
        }
    }
}
