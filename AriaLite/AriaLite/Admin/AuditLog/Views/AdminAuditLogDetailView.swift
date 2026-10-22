//
//  AdminAuditLogDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di una modifica: la frase, tutti i campi che il server dà e, quando ci sono, i valori prima e dopo.
//

import SwiftUI

struct AdminAuditLogDetailView: View {
    let detail: AdminAuditLogDetail

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                card("Details") {
                    ForEach(detail.fields) { field in
                        LabeledContent(field.label) {
                            Text(field.value)
                                .multilineTextAlignment(.trailing)
                        }
                        .font(.subheadline)
                    }
                }
                if !detail.changes.isEmpty {
                    card("Changes") {
                        ForEach(detail.changes) { change in
                            changeRow(change)
                        }
                    }
                }
                if let note = detail.note {
                    card("Changes") {
                        Text(note)
                            .font(.subheadline)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .ariaReadableWidth()
        }
        .liteBackground()
        .navigationTitle("Change")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: detail.icon)
                .font(.title)
                .foregroundStyle(detail.tone.color)
                .accessibilityHidden(true)
            Text(detail.title)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// "Campo: prima → dopo". Un valore mancante è un trattino.
    private func changeRow(_ change: AdminAuditLogChangeItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(change.field)
                .font(.subheadline.weight(.semibold))
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(change.old)
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(change.new)
            }
            .font(.subheadline)
            .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func card<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
