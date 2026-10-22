//
//  AdminInspectionDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un'ispezione, come /inspections/{id} della web: intestazione, avanzamento, stato,
//  checklist compilabile e note. "Edit" apre il form; il menu ha "Improve with AI" ed "Delete".
//

import SwiftUI

struct AdminInspectionDetailView: View {
    @State private var viewModel: AdminInspectionDetailViewModel

    @State private var isEditing = false
    @State private var aiViewModel: AdminInspectionAIViewModel?
    @Environment(\.dismiss) private var dismiss

    init(viewModel: AdminInspectionDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AdminInspectionHeader(inspection: viewModel.inspection, plantName: viewModel.plantName)
                if let message = viewModel.loadError {
                    AdminSectionNotice(text: message, isError: true)
                }
                if viewModel.inspection.totalCount > 0 { AdminInspectionProgressCard(inspection: viewModel.inspection) }
                AdminInspectionActionsCard(viewModel: viewModel)
                AdminInspectionChecklistCard(viewModel: viewModel)
                if let notes = viewModel.inspection.notes { notesCard(notes) }
            }
            .padding(20)
            .ariaReadableWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        .liteBackground()
        .navigationTitle("Inspection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { isEditing = true }
                    .disabled(!viewModel.canEdit)
            }
            ToolbarItem(placement: .topBarTrailing) { menu }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .sheet(isPresented: $isEditing) {
            AdminInspectionFormView(viewModel: viewModel.makeFormViewModel()) { viewModel.saved($0) }
        }
        .sheet(item: $aiViewModel, onDismiss: { Task { await viewModel.load() } }) { ai in
            AdminInspectionAIView(viewModel: ai)
        }
        .alert("Couldn't update the inspection", isPresented: $viewModel.showsActionError) {
            Button("OK") {}
        } message: {
            Text(viewModel.actionError ?? "")
        }
        .confirmationDialog("Delete this inspection?", isPresented: $viewModel.showsDeleteConfirmation,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { if await viewModel.delete() { dismiss() } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The inspection and its checklist will be removed. This can't be undone.")
        }
        .confirmationDialog("Some checks are still open", isPresented: $viewModel.showsCompleteConfirmation,
                            titleVisibility: .visible) {
            Button("Complete anyway") { Task { await viewModel.perform(.complete) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(viewModel.inspection.uncheckedCount) checks have not been done.")
        }
    }

    private var menu: some View {
        Menu {
            Button("Improve with AI", systemImage: "sparkles") { aiViewModel = viewModel.makeAIViewModel() }
                .disabled(!viewModel.canEdit)
            Button("Delete", systemImage: "trash", role: .destructive) { viewModel.showsDeleteConfirmation = true }
                .disabled(!viewModel.canEdit || viewModel.isWorking)
        } label: {
            Label("More", systemImage: "ellipsis.circle")
        }
    }

    private func notesCard(_ notes: String) -> some View {
        AdminCard(title: "Notes", systemImage: "text.alignleft") {
            Text(notes)
                .font(.subheadline)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
