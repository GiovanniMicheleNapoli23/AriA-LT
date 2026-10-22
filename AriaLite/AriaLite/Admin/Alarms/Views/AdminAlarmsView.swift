//
//  AdminAlarmsView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Alarms, come la pagina /alarms della web: filtri per stato in alto, ricerca per codice,
//  descrizione e asset, una scheda per allarme, dettaglio a tocco. "Select" sulle bozze permette di
//  approvarne più d'una insieme (con conferma).
//

import SwiftUI

struct AdminAlarmsView: View {
    @Bindable var viewModel: AdminAlarmsViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AdminAlarmStatusFilterBar(viewModel: viewModel)
                        .padding(.top, 8)
                    errorPill
                    notice
                    content
                }
                .ariaReadableWidth()
            }
            .refreshable { await viewModel.refresh() }
            .liteBackground()
            .navigationTitle("Alarms")
            .navigationDestination(for: AdminAlarm.self) { alarm in
                AdminAlarmDetailView(alarm: alarm, owner: viewModel)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isSelecting {
                        Button("Done") { withAnimation(.snappy) { viewModel.endSelecting() } }
                    } else if viewModel.canSelect {
                        Button("Select") { withAnimation(.snappy) { viewModel.startSelecting() } }
                    }
                }
            }
            .searchable(text: $viewModel.query, prompt: Text("Code, description, asset..."))
            .ariaBottomBar {
                if viewModel.isSelecting { AdminAlarmSelectionBar(viewModel: viewModel) }
            }
            .confirmationDialog(viewModel.approveConfirmationTitle, isPresented: $viewModel.showsApproveConfirmation,
                                titleVisibility: .visible) {
                Button("Approve") { Task { await viewModel.approveSelected() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(verbatim: viewModel.approveConfirmationMessage)
            }
            .alert("Couldn't approve the alarms", isPresented: $viewModel.isShowingApproveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(verbatim: viewModel.approveError ?? "")
            }
        }
        .task(id: viewModel.loadKey) { await viewModel.loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        if let placeholder = viewModel.placeholder {
            AdminAlarmsPlaceholder(placeholder: placeholder, retry: { Task { await viewModel.refresh() } })
        } else {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.visibleAlarms) { alarm in
                    row(alarm)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)

            if let updated = viewModel.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private func row(_ alarm: AdminAlarm) -> some View {
        if viewModel.isSelecting {
            Button { viewModel.toggle(alarm) } label: {
                AdminAlarmRow(alarm: alarm, isSelected: viewModel.selection.contains(alarm.id))
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: alarm) {
                AdminAlarmRow(alarm: alarm)
            }
            .buttonStyle(.plain)
        }
    }

    /// L'esito dell'ultima approvazione in blocco.
    @ViewBuilder
    private var notice: some View {
        if let notice = viewModel.notice {
            Label(notice, systemImage: "checkmark.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.green)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .ariaGlass(in: Capsule())
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
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
            .padding(.top, 8)
        }
    }
}
