//
//  AdminCraftedWidgetDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un widget: i dati di oggi disegnati con le card della chat (tabella, grafico, KPI…)
//  o come contenuto strutturato, e la "ricetta" (tool e argomenti). Eliminazione con conferma.
//

import SwiftUI

struct AdminCraftedWidgetDetailView: View {
    @State private var viewModel: AdminCraftedWidgetDetailViewModel
    let canDelete: Bool
    /// Elimina il widget; restituisce il motivo se non è riuscito.
    let onDelete: () async -> String?

    @State private var confirmsDelete = false
    @State private var deleteError: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    init(viewModel: AdminCraftedWidgetDetailViewModel, canDelete: Bool, onDelete: @escaping () async -> String?) {
        _viewModel = State(initialValue: viewModel)
        self.canDelete = canDelete
        self.onDelete = onDelete
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let deleteError {
                    AdminSectionNotice(text: deleteError, isError: true)
                }
                content
                recipe
            }
            .padding(20)
            .ariaReadableWidth()
        }
        .liteBackground()
        .navigationTitle(viewModel.widget.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Delete", systemImage: "trash", role: .destructive) { confirmsDelete = true }
                    .disabled(!canDelete)
            }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .confirmationDialog("Delete this widget?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    deleteError = await onDelete()
                    if deleteError == nil { dismiss() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("“\(viewModel.widget.displayTitle)” will be removed from Crafted. The data it shows isn't touched.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(viewModel.kindLabel, systemImage: viewModel.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.liteAccent)
            Text(viewModel.widget.displayTitle)
                .font(.title2.weight(.bold))
            if let description = viewModel.widget.description {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            if let plant = viewModel.plantName {
                Label(plant, systemImage: "building.2")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let message = viewModel.errorMessage {
            AdminSectionNotice(text: message, isError: true)
        }
        switch viewModel.render {
        case .artifact(let artifact)?:
            AriaArtifactView(artifact: artifact, actions: AriaArtifactActions(open: { path in
                if let url = viewModel.webURL(for: path) { openURL(url) }
            }))
            updatedLine
        case .structured(let json)?:
            AdminCraftedStructuredContent(fields: viewModel.fields(of: json), tables: viewModel.tables(of: json),
                                          nested: viewModel.nested(of: json))
            updatedLine
        case .empty?:
            AdminSectionNotice(text: String(localized: "The tool returned no data for this plant right now."),
                               systemImage: "tray")
        case nil:
            if viewModel.isLoading {
                ProgressView("Refreshing the data…")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
        }
    }

    @ViewBuilder
    private var updatedLine: some View {
        if let date = viewModel.renderedAt {
            Text("Data as of \(date.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
        }
    }

    private var recipe: some View {
        AdminCard(title: "How it's made", systemImage: "function") {
            VStack(alignment: .leading, spacing: 0) {
                AdminFieldRow(field: AdminAssetField(title: String(localized: "Tool"), value: viewModel.widget.toolName),
                              showsDivider: !viewModel.argumentFields.isEmpty)
                ForEach(viewModel.argumentFields) { field in
                    AdminFieldRow(field: field, showsDivider: field != viewModel.argumentFields.last)
                }
            }
        }
    }
}
