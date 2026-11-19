//
//  AdminUserTodaySection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda Oggi (§4.1), in sezioni di una List: dove si trova la persona, i team di appartenenza, le competenze e,
//  con `assign_shifts`, "Sposta in un team oggi" (turno + team: scegliere il team assegna subito).
//

import SwiftUI

struct AdminUserTodaySection: View {
    let details: AdminMember?
    let viewModel: AdminUserShiftsViewModel

    var body: some View {
        if let details {
            placementSection(details)
            homeTeamsSection(details)
            skillsSection(details)
            if viewModel.canAssignShifts { moveSection(details) }
        } else {
            Section {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Loading…").foregroundStyle(.secondary)
                }
            }
        }
    }

    private func placementSection(_ details: AdminMember) -> some View {
        Section("Current placement") {
            if let placement = viewModel.placement(of: details) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(verbatim: placement.team)
                        if placement.isAdHoc { AdminMemberBadge(text: String(localized: "Ad hoc"), tint: .orange) }
                    }
                    if let shift = placement.shift {
                        Text(verbatim: shift)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            } else {
                Text("No team assigned today").foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func homeTeamsSection(_ details: AdminMember) -> some View {
        if !details.homeTeams.isEmpty {
            Section("Home teams") {
                AdminMobileUserFlowLayout {
                    ForEach(details.homeTeams) { team in
                        AdminUserTeamChip(title: viewModel.title(of: team))
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func skillsSection(_ details: AdminMember) -> some View {
        Section("Skills") {
            if details.specialties.isEmpty {
                Text("No skill assigned (manage them from the Teams page)").foregroundStyle(.secondary)
            } else {
                AdminMobileUserFlowLayout {
                    ForEach(details.specialties, id: \.self) { specialty in
                        AdminMobileUserSpecialtyChip(title: specialty)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func moveSection(_ details: AdminMember) -> some View {
        Section("Move to a team today") {
            Picker("Shift", selection: Binding(get: { viewModel.moveShift }, set: { viewModel.chooseMoveShift($0) })) {
                ForEach(AdminUserShiftsViewModel.shiftOptions) { type in
                    Text(verbatim: type.localized).tag(type)
                }
            }
            NavigationLink {
                AdminUserTeamPickerView(viewModel: viewModel, title: "Destination team", selectedId: nil) { team in
                    Task { await viewModel.moveToday(to: team) }
                }
            } label: {
                LabeledContent("Destination team") {
                    if viewModel.isMoving {
                        ProgressView()
                    } else {
                        Text("Select team…").foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(viewModel.isMoving)
        }
        .onChange(of: details.currentShift, initial: true) { _, current in
            viewModel.seedMoveShift(from: current)
        }
    }
}
