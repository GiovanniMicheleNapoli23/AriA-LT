//
//  AdminUserHistoryView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La pagina Cronologia (§4.3): tutti i turni della persona, un giorno per sezione, il più recente per primo, con
//  "Today" su quello di oggi (UTC). Con `assign_shifts`, un turno di oggi o futuro si toglie con lo scorrimento
//  ("Remove") dopo una conferma.
//

import SwiftUI

struct AdminUserHistoryView: View {
    @Bindable var viewModel: AdminUserShiftsViewModel

    var body: some View {
        List {
            switch viewModel.history {
            case .loading:
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Loading…").foregroundStyle(.secondary)
                    }
                }
            case .failed(let message):
                Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                    Button("Retry") { Task { await viewModel.loadHistory() } }
                }
            case .loaded(let days):
                if days.isEmpty {
                    Section {
                        Text("No shift recorded in the last 2 weeks.").foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(days) { day in dayRows(day) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .liteBackground()
        .ariaReadableWidth()
        .refreshable { await viewModel.loadHistory() }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .adminUsersToast(viewModel.owner)
        .alert("Remove assignment", isPresented: $viewModel.isConfirmingRemoval, presenting: viewModel.shiftToRemove) { shift in
            Button("Remove", role: .destructive) { Task { await viewModel.remove(shift) } }
            Button("Cancel", role: .cancel) {}
        } message: { shift in
            Text(verbatim: viewModel.removalMessage(for: shift))
        }
        .task { await viewModel.loadHistory() }
    }

    private func dayRows(_ day: AdminUserShiftDay) -> some View {
        Section {
            ForEach(day.shifts) { shift in
                AdminUserShiftRow(shift: shift)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if viewModel.canRemove(shift) {
                            Button("Remove", systemImage: "trash", role: .destructive) { viewModel.requestRemoval(shift) }
                        }
                    }
                    .contextMenu {
                        if viewModel.canRemove(shift) {
                            Button("Remove", systemImage: "trash", role: .destructive) { viewModel.requestRemoval(shift) }
                        }
                    }
            }
        } header: {
            HStack(spacing: 8) {
                Text(verbatim: day.title)
                if viewModel.isToday(day) { AdminMemberBadge(text: String(localized: "Today")) }
            }
            .textCase(nil)
        }
    }
}
