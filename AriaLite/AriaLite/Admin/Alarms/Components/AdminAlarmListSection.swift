//
//  AdminAlarmListSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una sezione del modulo con un elenco di righe di testo (cause, passi): si scrive, si scorre per
//  eliminare, "Add" aggiunge una riga vuota.
//

import SwiftUI

struct AdminAlarmListSection: View {
    let title: LocalizedStringKey
    let addTitle: LocalizedStringKey
    @Binding var items: [AdminAlarmListItem]
    let add: () -> Void

    var body: some View {
        Section(title) {
            ForEach($items) { $item in
                TextField(title, text: $item.text, axis: .vertical)
                    .lineLimit(1...5)
            }
            .onDelete { items.remove(atOffsets: $0) }
            Button(action: add) {
                Label(addTitle, systemImage: "plus.circle")
            }
        }
    }
}
