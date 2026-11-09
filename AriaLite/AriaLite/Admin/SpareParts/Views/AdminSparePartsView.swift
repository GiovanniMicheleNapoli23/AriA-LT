//
//  AdminSparePartsView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I ricambi, come la pagina /spare-parts della web: filtri in alto, ricerca, una scheda per ricambio
//  (quelli sotto scorta in evidenza), dettaglio a tocco e "+" per crearne uno nuovo.
//

import SwiftUI

struct AdminSparePartsView: View {
    @Bindable var viewModel: AdminSparePartsViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AdminSparePartFilterBar(viewModel: viewModel)
                        .padding(.top, 8)
                    errorPill
                    content
                }
                .ariaReadableWidth()
            }
            .refreshable { await viewModel.refresh() }
            .liteBackground()
            .navigationTitle("Spare Parts")
            .navigationDestination(for: AdminSparePart.self) { part in
                AdminSparePartDetailView(part: part, owner: viewModel)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New spare part", systemImage: "plus") { viewModel.startCreating() }
                }
            }
            .searchable(text: $viewModel.query, prompt: Text("Code, name, part number, barcode..."))
            .sheet(item: $viewModel.newPartForm) { form in
                AdminSparePartFormView(viewModel: form)
            }
        }
        .task(id: viewModel.loadKey) { await viewModel.loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        if let placeholder = viewModel.placeholder {
            AdminSparePartsPlaceholder(placeholder: placeholder,
                                       retry: { Task { await viewModel.refresh() } },
                                       clearFilters: { withAnimation(.snappy) { viewModel.clearFilters() } })
        } else {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.visibleParts) { part in
                    NavigationLink(value: part) {
                        AdminSparePartRow(part: part)
                    }
                    .buttonStyle(.plain)
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
