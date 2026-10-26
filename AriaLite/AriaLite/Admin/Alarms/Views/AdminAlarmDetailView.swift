//
//  AdminAlarmDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un allarme (pagina /alarms/{id} della web): intestazione, approvazione se è una bozza,
//  scheda, cause tipiche, passi di risoluzione e diagnosi. "Edit" apre il modulo; l'AI è il blob di
//  Aria in basso a destra, come nel dettaglio di un ordine.
//

import SwiftUI

struct AdminAlarmDetailView: View {
    @State private var viewModel: AdminAlarmDetailViewModel

    init(alarm: AdminAlarm, owner: AdminAlarmsViewModel) {
        _viewModel = State(initialValue: AdminAlarmDetailViewModel(alarm: alarm, owner: owner))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        @Bindable var diagnosis = viewModel.diagnosis
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AdminAlarmHeader(alarm: viewModel.alarm)
                if let failure = viewModel.failure { AdminAlarmFailureNote(failure: failure) }
                if viewModel.canApprove || viewModel.isApproving {
                    AdminAlarmApproveBanner(isApproving: viewModel.isApproving) {
                        viewModel.showsApproveConfirmation = true
                    }
                }
                if !viewModel.infoRows.isEmpty { AdminAlarmInfoCard(rows: viewModel.infoRows) }
                AdminAlarmLinesCard(title: "Typical causes", systemImage: "questionmark.diamond",
                                    lines: viewModel.alarm.typicalCauses)
                AdminAlarmLinesCard(title: "Resolution steps", systemImage: "list.number",
                                    lines: viewModel.alarm.resolutionSteps, isNumbered: true)
                AdminAlarmDiagnoseCard(viewModel: diagnosis)
            }
            .padding(20)
            .ariaReadableWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        // Spazio sotto l'ultimo contenuto: il pulsante di Aria non copre niente.
        .contentMargins(.bottom, 96, for: .scrollContent)
        .overlay(alignment: .bottomTrailing) {
            AdminWorkOrderAssistantButton(label: "Improve with AI") { viewModel.startImproving() }
                .padding(.trailing, 20)
                .padding(.bottom, 12)
                .ignoresSafeArea(.keyboard)
        }
        .liteBackground()
        .navigationTitle(Text(verbatim: viewModel.alarm.code))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { viewModel.startEditing() }
            }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .onDisappear { viewModel.cancel() }
        .sheet(item: $viewModel.editForm) { form in
            AdminAlarmFormView(viewModel: form)
        }
        .sheet(item: $viewModel.improve) { improve in
            AdminAlarmImproveView(viewModel: improve)
        }
        .sheet(item: $diagnosis.workOrderForm) { form in
            AdminAlarmWorkOrderFormView(viewModel: form)
        }
        .alert("Approve this alarm?", isPresented: $viewModel.showsApproveConfirmation) {
            Button("Approve") { Task { await viewModel.approve() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It will be added to the knowledge base the assistant draws on.")
        }
        .alert("Couldn't approve the alarm", isPresented: $viewModel.isShowingApproveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: viewModel.approveError ?? "")
        }
    }
}
