//
//  AdminCraftedAriaScopeList.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Su cosa lavora Aria: l'elenco dei blocchi del documento (le risposte di un artifact, i paragrafi di un
//  rapporto) con la spunta su quelli scelti. Niente di scelto vuol dire tutto il documento.
//

import SwiftUI

struct AdminCraftedAriaScopeList: View {
    let choices: [AdminCraftedAriaChoice]
    @Binding var selection: Set<String>

    var body: some View {
        List {
            Section {
                ForEach(choices) { choice in
                    Button { toggle(choice.id) } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: selection.contains(choice.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selection.contains(choice.id) ? Color.liteAccent : .secondary)
                            Text(choice.title).font(.callout).lineLimit(4).multilineTextAlignment(.leading)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection.contains(choice.id) ? .isSelected : [])
                }
            } footer: {
                Text("Aria will only change what you picked. With nothing picked, it works on the whole document.")
            }
        }
        .navigationTitle("Choose what to change")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Whole document") { selection = [] }
                    .disabled(selection.isEmpty)
            }
        }
    }

    private func toggle(_ id: String) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }
}
