//
//  AdminWorkOrderChoiceList.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Scelta da un elenco lungo (asset, persone, squadre), aperta dal form: si cerca, si tocca una voce e si
//  torna indietro. "None" toglie la scelta.
//

import SwiftUI

struct AdminWorkOrderChoiceList: View {
    let title: String
    let choices: [AdminWorkOrderChoice]
    let selection: String?
    let onSelect: (String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        List {
            Button { pick(nil) } label: { row(String(localized: "None"), subtitle: nil, isSelected: selection == nil) }
            ForEach(AdminWorkOrderChoice.matching(query, in: choices)) { choice in
                Button { pick(choice.id) } label: {
                    row(choice.title, subtitle: choice.subtitle, isSelected: choice.id == selection)
                }
            }
        }
        .overlay {
            if choices.isEmpty {
                ContentUnavailableView("Nothing to choose from", systemImage: "tray")
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func pick(_ id: String?) {
        onSelect(id)
        dismiss()
    }

    private func row(_ title: String, subtitle: String?, isSelected: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(.primary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark").foregroundStyle(Color.liteAccent).fontWeight(.semibold)
            }
        }
        .contentShape(Rectangle())
    }
}
