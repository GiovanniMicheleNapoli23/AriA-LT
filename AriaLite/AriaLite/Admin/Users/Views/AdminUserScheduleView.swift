//
//  AdminUserScheduleView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La pagina Pianifica (§4.2): assegna la persona a un team in un giorno futuro o passato. Data, turno e team, poi
//  "Schedule". La pagina si apre solo se chi guarda può assegnare turni (lo decide la scheda).
//

import SwiftUI

struct AdminUserScheduleView: View {
    @Bindable var viewModel: AdminUserShiftsViewModel

    var body: some View {
        List {
            Section {
                DatePicker("Date", selection: $viewModel.scheduleDate, displayedComponents: .date)
                Picker("Shift", selection: $viewModel.scheduleShift) {
                    ForEach(AdminUserShiftsViewModel.shiftOptions) { type in
                        Text(verbatim: type.localized).tag(type)
                    }
                }
                NavigationLink {
                    AdminUserTeamPickerView(viewModel: viewModel, title: "Team", selectedId: viewModel.scheduleTeam?.id) { team in
                        viewModel.chooseScheduleTeam(team)
                    }
                } label: {
                    LabeledContent("Team") {
                        if let team = viewModel.scheduleTeam {
                            Text(verbatim: team.name)
                        } else {
                            Text("Select team…").foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: {
                Text("Add an assignment to a team for a future or past date. Overwrites the same (date + shift) if it already exists.")
            }
            Section {
                Button {
                    Task { await viewModel.schedule() }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isScheduling { ProgressView() }
                        Text(LocalizedStringResource("users.schedule.submit", defaultValue: "Schedule"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.liteAccent)
                .foregroundStyle(Color.liteOnAccent)
                .disabled(!viewModel.canSchedule)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .liteBackground()
        .ariaReadableWidth()
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .adminUsersToast(viewModel.owner)
        .task { await viewModel.loadTeams() }
    }
}
