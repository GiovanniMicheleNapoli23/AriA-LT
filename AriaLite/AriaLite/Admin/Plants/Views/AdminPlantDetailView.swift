//
//  AdminPlantDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di uno stabilimento: campi e date, con modifica ed eliminazione (conferma prima).
//

import SwiftUI

struct AdminPlantDetailView: View {
    @State private var viewModel: AdminPlantDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(plant: AdminPlant, owner: AdminPlantsViewModel) {
        _viewModel = State(initialValue: AdminPlantDetailViewModel(plant: plant, owner: owner))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(verbatim: viewModel.plant.name)
                        .font(.title3.weight(.bold))
                        .textSelection(.enabled)
                    HStack(spacing: 10) {
                        AdminPlantCodeBadge(code: viewModel.plant.code)
                        if viewModel.isActive { AdminPlantActiveBadge() }
                    }
                }
                .padding(.vertical, 4)
            }

            if !viewModel.detailRows.isEmpty {
                Section {
                    ForEach(viewModel.detailRows, id: \.label) { row in
                        LabeledContent(row.label) {
                            Text(verbatim: row.value).textSelection(.enabled)
                        }
                    }
                }
            }

            if let description = viewModel.plant.description {
                Section("Description") {
                    Text(verbatim: description).textSelection(.enabled)
                }
            }

            if !viewModel.dateRows.isEmpty {
                Section("Dates") {
                    ForEach(viewModel.dateRows, id: \.label) { row in
                        LabeledContent(row.label) {
                            Text(verbatim: row.value)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .liteBackground()
        .navigationTitle(Text(verbatim: viewModel.plant.name))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { viewModel.startEditing() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.isDeleting {
                    ProgressView()
                } else {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        viewModel.showsDeleteConfirmation = true
                    }
                }
            }
        }
        .sheet(item: $viewModel.editForm) { form in
            AdminPlantFormView(viewModel: form)
        }
        .alert("Delete this plant?", isPresented: $viewModel.showsDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { if await viewModel.delete() { dismiss() } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("""
                “\(viewModel.plant.name)” will be removed. \
                Data linked to this plant can block the deletion. \
                This can't be undone.
                """)
        }
        .alert("Couldn't delete the plant", isPresented: $viewModel.isShowingDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: viewModel.deleteError ?? "")
        }
    }
}
