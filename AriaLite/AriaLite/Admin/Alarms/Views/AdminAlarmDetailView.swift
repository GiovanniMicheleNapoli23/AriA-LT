//
//  AdminAlarmDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un allarme (pagina /alarms/{id} della web): intestazione con i fatti, stato di revisione
//  (le decisioni nella barra in basso), cause tipiche, passi di risoluzione e diagnosi. "Edit" apre il modulo;
//  l'AI è il blob di Aria in basso a destra, sopra la barra, come nel dettaglio di un ordine (e le sezioni vuote
//  offrono di completarle).
//

import SwiftUI

struct AdminAlarmDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AdminAlarmDetailViewModel

    init(alarm: AdminAlarm, owner: AdminAlarmsViewModel) {
        _viewModel = State(initialValue: AdminAlarmDetailViewModel(alarm: alarm, owner: owner))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        @Bindable var diagnosis = viewModel.diagnosis
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AdminAlarmHeader(viewModel: viewModel)
                if let failure = viewModel.failure { AdminAlarmFailureNote(failure: failure) }
                AdminAlarmLinesCard(title: "Typical causes", systemImage: "questionmark.diamond",
                                    lines: viewModel.alarm.typicalCauses, fillIn: { viewModel.startImproving() })
                AdminAlarmLinesCard(title: "Resolution steps", systemImage: "list.number",
                                    lines: viewModel.alarm.resolutionSteps, isNumbered: true,
                                    fillIn: { viewModel.startImproving() })
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
        .ariaBottomBar {
            if viewModel.showsReview {
                AdminReviewDecisionBar(actions: viewModel.reviewActions, running: viewModel.reviewing,
                                       error: viewModel.reviewError, perform: { viewModel.requestReview($0) })
            }
        }
        .liteBackground()
        // Il codice è già nell'intestazione: il titolo dice solo dove si è.
        .navigationTitle("Alarm")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { viewModel.startEditing() }
                    .disabled(viewModel.isDeleting)
            }
            // L'azione distruttiva non sta accanto a Edit: va nel menu, come negli altri dettagli.
            if viewModel.canDelete || viewModel.isDeleting {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isDeleting {
                        ProgressView()
                    } else {
                        Menu("More", systemImage: "ellipsis.circle") {
                            Button("Delete", systemImage: "trash", role: .destructive) { viewModel.showsDeleteConfirmation = true }
                        }
                    }
                }
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
        .adminReviewConfirmation(isPresented: $viewModel.isConfirmingReview, action: viewModel.confirmingReview) { action in
            Task { await viewModel.review(action) }
        }
        .alert("Delete this alarm?", isPresented: $viewModel.showsDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { if await viewModel.delete() { dismiss() } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("“\(viewModel.alarm.code)” will be removed from your alarms. This can't be undone.")
        }
        .alert("Couldn't delete the alarm", isPresented: $viewModel.isShowingDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: viewModel.deleteError ?? "")
        }
    }
}
