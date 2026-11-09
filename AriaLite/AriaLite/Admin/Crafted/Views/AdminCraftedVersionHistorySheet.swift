//
//  AdminCraftedVersionHistorySheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  La cronologia versioni in un foglio: dalla più nuova all'originale di Aria, ognuna con chi e quando,
//  cosa si era chiesto ad Aria e quanto ha cambiato. Toccarne una la apre a confronto. Riceve solo le
//  righe già scritte (AdminCraftedVersionHistoryEntry): serve uguale per artifact e report.
//

import SwiftUI

struct AdminCraftedVersionHistorySheet: View {
    let entries: [AdminCraftedVersionHistoryEntry]
    /// La versione già aperta a confronto, se c'è.
    var selected: Int?
    let onSelect: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(entries) { entry in
                Button { onSelect(entry.number) } label: { row(entry) }
                    .buttonStyle(.plain)
                    .listRowBackground(entry.number == selected ? Color.liteAccent.opacity(0.1) : nil)
            }
            .listStyle(.plain)
            .navigationTitle("Version history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ entry: AdminCraftedVersionHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(entry.label).font(.subheadline.weight(.semibold))
                if entry.isCurrent { AriaBadge(text: String(localized: "Current"), tint: Color.liteAccent) }
            }
            Text(entry.byline).font(.footnote).foregroundStyle(.secondary)
            if let detail = entry.detail {
                Text(detail).font(.footnote.italic())
            }
            Text(entry.summary).font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
