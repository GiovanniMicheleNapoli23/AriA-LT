//
//  AdminAssetDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un asset, come /assets/{tag} della web: intestazione, disponibilità degli ultimi
//  30 giorni, fermi macchina, ordini di lavoro e scheda tecnica. "Edit" in alto apre il form.
//

import SwiftUI

struct AdminAssetDetailView: View {
    @State private var viewModel: AdminAssetDetailViewModel

    @State private var isEditing = false
    @State private var downtimeForm: AdminDowntimeFormViewModel?

    init(viewModel: AdminAssetDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AdminAssetHeader(asset: viewModel.asset, place: viewModel.placeLine)
                if let message = viewModel.assetError {
                    AdminSectionNotice(text: message, isError: true)
                }
                if viewModel.asset.description != nil || viewModel.asset.notes != nil { textCard }
                AdminAssetStatsCard(viewModel: viewModel)
                AdminAssetDowntimeCard(viewModel: viewModel) { downtime in
                    downtimeForm = viewModel.makeDowntimeForm(editing: downtime)
                }
                AdminAssetWorkOrdersCard(viewModel: viewModel)
                detailsCard
            }
            .padding(20)
            .ariaReadableWidth()
        }
        .liteBackground()
        .navigationTitle(viewModel.asset.tag)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { isEditing = true }
                    .disabled(!viewModel.canEdit)
            }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .sheet(isPresented: $isEditing) {
            AdminAssetFormView(viewModel: viewModel.makeAssetForm()) { viewModel.assetSaved($0) }
        }
        .sheet(item: $downtimeForm) { form in
            AdminDowntimeFormView(viewModel: form) { saved in
                Task { await viewModel.downtimeSaved(saved) }
            }
        }
        .alert("Couldn't update downtime", isPresented: $viewModel.showsActionError) {
            Button("OK") {}
        } message: {
            Text(viewModel.actionError ?? "")
        }
        .alert("Delete this downtime?", isPresented: $viewModel.showsDeleteConfirmation,
               presenting: viewModel.downtimeToDelete) { downtime in
            Button("Delete", role: .destructive) { Task { await viewModel.delete(downtime) } }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("The uptime statistics of this asset will be recalculated.")
        }
    }

    // MARK: Testi e scheda

    private var textCard: some View {
        AdminCard(title: "Description", systemImage: "text.alignleft") {
            VStack(alignment: .leading, spacing: 10) {
                if let description = viewModel.asset.description {
                    Text(description)
                        .font(.subheadline)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let notes = viewModel.asset.notes {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(notes)
                            .font(.subheadline)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var detailsCard: some View {
        AdminCard(title: "Details", systemImage: "info.circle") {
            let fields = viewModel.fields
            VStack(spacing: 0) {
                ForEach(fields) { field in
                    AdminFieldRow(field: field, showsDivider: field != fields.last)
                }
            }
        }
    }
}
