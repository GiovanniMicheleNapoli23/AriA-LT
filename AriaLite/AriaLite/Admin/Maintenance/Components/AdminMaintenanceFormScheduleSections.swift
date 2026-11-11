//
//  AdminMaintenanceFormScheduleSections.swift
//  AriaLite
//
//  Created by Giovanni Michele on 11/11/26.
//
//  Le sezioni del foglio di un piano dopo "Where": programmazione (frequenza, giorni, intervallo, durata),
//  date facoltative, passi e ricambi uno per riga, descrizione.
//

import SwiftUI

struct AdminMaintenanceFormScheduleSections: View {
    @Bindable var viewModel: AdminMaintenanceFormViewModel
    var focus: FocusState<Bool>.Binding

    var body: some View {
        Section("Schedule") {
            Picker("Frequency", selection: $viewModel.frequency) {
                ForEach(viewModel.frequencyOptions, id: \.self) { Text(viewModel.frequencyLabel($0)).tag($0) }
            }
            if viewModel.showsDays {
                AdminMaintenanceDaysPicker(days: $viewModel.days)
                    .padding(.vertical, 4)
            }
            numberRow("Interval (hours)", text: $viewModel.frequencyHours, keyboard: .decimalPad)
            numberRow("Estimated duration (minutes)", text: $viewModel.estimatedDuration, keyboard: .numberPad)
        }
        .tint(Color.liteAccent)

        Section("Dates") {
            AdminMaintenanceOptionalDateRow(title: "Next due", date: $viewModel.nextDueAt)
            AdminMaintenanceOptionalDateRow(title: "Last done", date: $viewModel.lastDoneAt)
            AdminMaintenanceOptionalDateRow(title: "Starts on", date: $viewModel.startsOn)
            AdminMaintenanceOptionalDateRow(title: "Ends on", date: $viewModel.endsOn)
        }

        Section("Steps") {
            TextField("Steps", text: $viewModel.tasksText, prompt: Text("One step per line"), axis: .vertical)
                .lineLimit(3...12)
                .focused(focus)
        }
        Section("Spare parts") {
            TextField("Spare parts", text: $viewModel.sparePartsText, prompt: Text("One part per line"), axis: .vertical)
                .lineLimit(2...8)
                .focused(focus)
        }
        Section("Description") {
            TextField("Description", text: $viewModel.description, axis: .vertical)
                .lineLimit(2...8)
                .focused(focus)
        }
    }

    /// "Titolo … valore": il numero a destra, facoltativo.
    private func numberRow(_ title: LocalizedStringKey, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        LabeledContent(title) {
            TextField(title, text: text, prompt: Text("Optional"))
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .focused(focus)
        }
    }
}
