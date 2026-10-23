//
//  AdminCategoriesView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Categories, come la pagina /categories della web: filtri per tipo e stabilimento, ricerca per
//  nome, una riga per categoria, modifica a tocco, "+" per crearne una nuova ed eliminazione con conferma.
//

import SwiftUI

struct AdminCategoriesView: View {
    @Bindable var viewModel: AdminCategoriesViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AdminCategoryFilterBar(viewModel: viewModel)
                        .padding(.top, 8)
                    errorPill
                    content
                }
                .ariaReadableWidth()
            }
            .refreshable { await viewModel.refresh() }
            .liteBackground()
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New category", systemImage: "plus") { viewModel.startCreating() }
                }
            }
            .searchable(text: $viewModel.query, prompt: Text("Name"))
            .sheet(item: $viewModel.form) { form in
                AdminCategoryFormView(viewModel: form)
            }
            .alert("Delete category?", isPresented: $viewModel.isShowingDeleteConfirmation) {
                Button("Delete", role: .destructive) { Task { await viewModel.confirmDelete() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(viewModel.deleteMessage)
            }
            .alert("Couldn't delete the category", isPresented: $viewModel.isShowingDeleteError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.deleteError ?? "")
            }
        }
        .task(id: viewModel.loadKey) { await viewModel.loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        if let placeholder = viewModel.placeholder {
            AdminCategoriesPlaceholder(placeholder: placeholder,
                                       retry: { Task { await viewModel.refresh() } },
                                       clearFilters: { withAnimation(.snappy) { viewModel.clearFilters() } })
        } else {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.visibleCategories) { category in
                    Button {
                        viewModel.startEditing(category)
                    } label: {
                        AdminCategoryRow(category: category, plantName: viewModel.plantName(for: category))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Edit", systemImage: "pencil") { viewModel.startEditing(category) }
                        Button("Delete", systemImage: "trash", role: .destructive) { viewModel.askDelete(category) }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
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
