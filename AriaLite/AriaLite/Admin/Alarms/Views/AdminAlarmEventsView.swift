//
//  AdminAlarmEventsView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  L'inbox degli eventi di allarme, raggiungibile dalla campanella della lista Alarms: filtro All/Unread/Read,
//  le più recenti per prime, tira per aggiornare. Per gli eventi non letti, scorrimento o tenuta premuta per
//  segnarli come letti, e "Mark all read" in alto (con conferma): solo se il ruolo può `acknowledge`.
//

import SwiftUI

struct AdminAlarmEventsView: View {
    @Bindable var viewModel: AdminAlarmEventsViewModel

    var body: some View {
        List {
            AdminAlarmEventsFilterBar(viewModel: viewModel)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 4, trailing: 20))
            errorPill
            if let placeholder = viewModel.placeholder {
                AdminAlarmEventsPlaceholder(placeholder: placeholder, retry: { Task { await viewModel.refresh() } })
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(viewModel.visibleEvents) { event in
                    row(event)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .ariaReadableWidth()
        .refreshable { await viewModel.refresh() }
        .liteBackground()
        .navigationTitle("Alarm events")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.canMarkAll || viewModel.isMarkingAll {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isMarkingAll {
                        ProgressView()
                    } else {
                        Button("Mark all read", systemImage: "checkmark.circle") {
                            viewModel.showsMarkAllConfirmation = true
                        }
                    }
                }
            }
        }
        .task(id: viewModel.loadKey) { await viewModel.loadIfNeeded() }
        .alert("Mark all alarm events as read?", isPresented: $viewModel.showsMarkAllConfirmation) {
            Button("Mark all read") { Task { await viewModel.markAllRead() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every unread event of the current site will be marked as read.")
        }
        .alert("Couldn't update the alarm events", isPresented: $viewModel.isShowingActionError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: viewModel.actionError ?? "")
        }
    }

    private func row(_ event: AdminAlarmEvent) -> some View {
        AdminAlarmEventRow(event: event)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                if viewModel.canAcknowledge && !event.isRead { markReadButton(event).tint(.accentColor) }
            }
            .contextMenu {
                if viewModel.canAcknowledge && !event.isRead { markReadButton(event) }
            }
    }

    private func markReadButton(_ event: AdminAlarmEvent) -> some View {
        Button("Mark as read", systemImage: "checkmark.circle") {
            Task { await viewModel.markRead(event) }
        }
    }

    /// Lista già a schermo ma l'ultimo aggiornamento è fallito: una riga sottile.
    @ViewBuilder
    private var errorPill: some View {
        if viewModel.refreshFailed {
            HStack(spacing: 8) {
                Image(systemName: "wifi.exclamationmark").foregroundStyle(.orange)
                Text("Couldn't refresh")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Retry") { Task { await viewModel.refresh() } }
                    .font(.footnote.weight(.semibold))
                    .disabled(viewModel.isLoading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .ariaGlass(in: Capsule())
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }
}
