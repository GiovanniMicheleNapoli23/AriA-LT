//
//  AdminWorkOrderTemplatesView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I modelli di ordine, aperti dalla lista degli ordini. Si tocca un modello per modificarlo; il pulsante
//  a destra (o lo swipe verso destra) crea un ordine dal modello, lo swipe verso sinistra lo elimina,
//  entrambi con conferma. Ricerca e pull-to-refresh; la logica è in AdminWorkOrderTemplatesViewModel.
//

import SwiftUI

struct AdminWorkOrderTemplatesView: View {
    @Bindable var viewModel: AdminWorkOrderTemplatesViewModel

    init(viewModel: AdminWorkOrderTemplatesViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        List {
            if let notice = viewModel.notice {
                Section { noticeRow(notice) }
            }
            if viewModel.hasLoaded, let message = viewModel.errorMessage {
                Section {
                    Label(message, systemImage: viewModel.isForbidden ? "lock" : "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
            Section {
                ForEach(viewModel.visibleTemplates) { template in
                    row(template)
                }
            } footer: {
                if viewModel.hasLoaded, !viewModel.visibleTemplates.isEmpty {
                    Text("Tap a template to edit it. Use the button on the right to create a work order from it.")
                }
            }
        }
        .overlay { overlay }
        .refreshable { await viewModel.load() }
        .searchable(text: $viewModel.searchText, prompt: Text("Search title, category, asset or zone"))
        .navigationTitle("Templates")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("New Template", systemImage: "plus") { viewModel.startCreating() }
                    .disabled(!viewModel.canCreate)
            }
        }
        .sheet(item: $viewModel.form) { AdminWorkOrderTemplateFormView(viewModel: $0) }
        .confirmationDialog("Delete this template?", isPresented: $viewModel.isConfirmingDelete,
                            titleVisibility: .visible, presenting: viewModel.pendingDelete) { template in
            Button("Delete", role: .destructive) { Task { await viewModel.delete(template) } }
        } message: { template in
            Text("“\(template.title)” will be removed for everyone. Work orders already created from it stay.")
        }
        .confirmationDialog("Create a work order?", isPresented: $viewModel.isConfirmingApply,
                            titleVisibility: .visible, presenting: viewModel.pendingApply) { template in
            Button("Create Work Order") { Task { await viewModel.apply(template) } }
        } message: { template in
            Text("A new work order will be created from “\(template.title)”.")
        }
        .task(id: viewModel.backend.activePlantId) { await viewModel.loadIfNeeded() }
    }

    // MARK: Righe

    private func row(_ template: AdminWorkOrderTemplate) -> some View {
        let isBusy = viewModel.busyId == template.id
        return HStack(spacing: 8) {
            Button { viewModel.startEditing(template) } label: {
                AdminWorkOrderTemplateRow(title: template.title, subtitle: viewModel.subtitle(template),
                                          priority: viewModel.priority(template), steps: viewModel.stepsLabel(template),
                                          parts: viewModel.partsLabel(template), isBusy: isBusy)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button("Create Work Order", systemImage: "plus.square.on.square") { viewModel.confirmApply(template) }
                .labelStyle(.iconOnly)
                .font(.title3)
                .foregroundStyle(Color.liteAccent)
                .buttonStyle(.borderless)
        }
        .disabled(viewModel.busyId != nil)
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive) { viewModel.confirmDelete(template) }
            Button("Edit", systemImage: "pencil") { viewModel.startEditing(template) }
        }
        .swipeActions(edge: .leading) {
            Button("Create Work Order", systemImage: "plus.square.on.square") { viewModel.confirmApply(template) }
                .tint(.liteAccent)
        }
        .contextMenu {
            Button("Create Work Order", systemImage: "plus.square.on.square") { viewModel.confirmApply(template) }
            Button("Edit", systemImage: "pencil") { viewModel.startEditing(template) }
            Button("Delete", systemImage: "trash", role: .destructive) { viewModel.confirmDelete(template) }
        }
    }

    private func noticeRow(_ notice: String) -> some View {
        HStack(spacing: 8) {
            Label(notice, systemImage: "checkmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(.green)
            Spacer(minLength: 0)
            Button("Dismiss", systemImage: "xmark") { viewModel.dismissNotice() }
                .labelStyle(.iconOnly)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .buttonStyle(.borderless)
        }
    }

    // MARK: Stati vuoti

    @ViewBuilder
    private var overlay: some View {
        if !viewModel.hasLoaded {
            if let message = viewModel.errorMessage {
                if viewModel.isForbidden {
                    ContentUnavailableView("No access to templates", systemImage: "lock", description: Text(message))
                } else {
                    ContentUnavailableView {
                        Label("Can't load templates", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Retry", systemImage: "arrow.clockwise") { Task { await viewModel.load() } }
                            .ariaGlassButtonStyle()
                    }
                }
            } else {
                ProgressView()
            }
        } else if viewModel.visibleTemplates.isEmpty {
            if viewModel.isSearching {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else {
                ContentUnavailableView("No templates", systemImage: "doc.on.doc",
                                       description: Text("Save a work order you repeat often as a template."))
            }
        }
    }
}
