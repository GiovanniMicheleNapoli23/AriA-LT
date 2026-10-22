//
//  AdminMaintenanceFormScheduleCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le schede "Schedule" e "Steps & parts" del foglio di un piano: frequenza, intervallo, giorni, date e
//  durata; passi e ricambi uno per riga, descrizione.
//

import SwiftUI

struct AdminMaintenanceFormScheduleCard: View {
    @Bindable var viewModel: AdminMaintenanceFormViewModel
    var focus: FocusState<Bool>.Binding

    var body: some View {
        AdminCard(title: "Schedule", systemImage: "calendar") {
            VStack(alignment: .leading, spacing: 12) {
                AdminMaintenanceMenuRow(title: "Frequency", value: viewModel.frequencyLabel(viewModel.frequency)) {
                    Picker("Frequency", selection: $viewModel.frequency) {
                        ForEach(viewModel.frequencyOptions, id: \.self) { Text(viewModel.frequencyLabel($0)).tag($0) }
                    }
                }
                if viewModel.showsDays { AdminMaintenanceDaysPicker(days: $viewModel.days) }
                AdminMaintenanceTextField(title: "Interval (hours)", text: $viewModel.frequencyHours,
                                          prompt: "Optional", keyboard: .decimalPad, focus: focus)
                AdminMaintenanceTextField(title: "Estimated duration (minutes)", text: $viewModel.estimatedDuration,
                                          prompt: "Optional", keyboard: .numberPad, focus: focus)
                Divider()
                AdminMaintenanceOptionalDateRow(title: "Next due", date: $viewModel.nextDueAt)
                AdminMaintenanceOptionalDateRow(title: "Last done", date: $viewModel.lastDoneAt)
                AdminMaintenanceOptionalDateRow(title: "Starts on", date: $viewModel.startsOn)
                AdminMaintenanceOptionalDateRow(title: "Ends on", date: $viewModel.endsOn)
            }
        }
    }
}

struct AdminMaintenanceFormListsCard: View {
    @Bindable var viewModel: AdminMaintenanceFormViewModel
    var focus: FocusState<Bool>.Binding

    var body: some View {
        AdminCard(title: "Steps and parts", systemImage: "checklist") {
            VStack(alignment: .leading, spacing: 12) {
                AdminMaintenanceTextField(title: "Steps", text: $viewModel.tasksText, prompt: "One step per line",
                                          axis: .vertical, lines: 3...12, focus: focus)
                AdminMaintenanceTextField(title: "Spare parts", text: $viewModel.sparePartsText, prompt: "One part per line",
                                          axis: .vertical, lines: 2...8, focus: focus)
                AdminMaintenanceTextField(title: "Description", text: $viewModel.description, axis: .vertical,
                                          lines: 2...8, focus: focus)
            }
        }
    }
}
