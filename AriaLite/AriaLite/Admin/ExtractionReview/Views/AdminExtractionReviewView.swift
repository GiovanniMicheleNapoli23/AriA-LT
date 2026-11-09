//
//  AdminExtractionReviewView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Extraction Review, come la pagina /extraction/review della web: un segmento per tipo con
//  i pending, ricerca, "Select" per approvare in blocco, pressione lunga per approvare o rifiutare una
//  riga. Il dettaglio (correzione dei campi e AI) è in AdminExtractionDetailView.
//

import SwiftUI

struct AdminExtractionReviewView: View {
    @Bindable var viewModel: AdminExtractionReviewViewModel

    @State private var path: [AdminExtractionItem] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    AdminExtractionKindPicker(viewModel: viewModel)
                        .padding(.horizontal, 20)
                    errorPill
                    content
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
                .ariaReadableWidth()
            }
            .refreshable { await viewModel.load() }
            .liteBackground()
            .navigationTitle("Extraction Review")
            .navigationDestination(for: AdminExtractionItem.self) { item in
                AdminExtractionDetailView(viewModel: viewModel.makeDetailViewModel(for: item))
            }
            .toolbar { toolbar }
            .searchable(text: $viewModel.searchText, prompt: Text("Search code, name, description"))
            .safeAreaInset(edge: .bottom) {
                if viewModel.isSelecting {
                    AdminExtractionSelectionBar(viewModel: viewModel)
                        .background(.bar)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: viewModel.isSelecting)
            .alert("Couldn't complete the review", isPresented: $viewModel.showsActionError) {
                Button("OK") {}
            } message: {
                Text(viewModel.actionError ?? "")
            }
        }
        .task(id: viewModel.loadKey) { await viewModel.load() }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
        ToolbarItem(placement: .topBarTrailing) {
            if viewModel.isSelecting {
                Button("Done") { viewModel.endSelection() }
            } else {
                Button("Select") { viewModel.beginSelection() }
                    .disabled(viewModel.visibleItems.isEmpty)
            }
        }
    }

    // MARK: Contenuto

    @ViewBuilder
    private var content: some View {
        let items = viewModel.visibleItems
        if items.isEmpty, let message = viewModel.loadError {
            // La lista non è arrivata: non si dice "niente da rivedere", si dice perché.
            VStack(spacing: 14) {
                ContentUnavailableView("Can't load the review", systemImage: "exclamationmark.triangle",
                                       description: Text(message))
                Button {
                    Task { await viewModel.load() }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .ariaGlassButtonStyle()
                .disabled(viewModel.isLoading)
            }
            .padding(.top, 40)
        } else if !viewModel.hasLoaded {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        } else if items.isEmpty {
            if viewModel.isSearching {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else {
                ContentUnavailableView("Nothing to review", systemImage: "checkmark.seal",
                                       description: Text("Every extracted item of this type has been reviewed."))
                    .padding(.top, 40)
            }
        } else {
            list(items)
        }
    }

    private func list(_ items: [AdminExtractionItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.subtitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)
                .padding(.top, 4)
            ForEach(items) { item in
                row(item)
                    .padding(.horizontal, 20)
            }
            if let updated = viewModel.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
            }
        }
    }

    @ViewBuilder
    private func row(_ item: AdminExtractionItem) -> some View {
        if viewModel.isSelecting {
            Button {
                viewModel.toggleSelection(item)
            } label: {
                AdminExtractionRow(item: item, isSelecting: true, isSelected: viewModel.isSelected(item),
                                   isBusy: viewModel.isBusy(item))
            }
            .buttonStyle(.plain)
            .disabled(!item.canEdit)
        } else {
            NavigationLink(value: item) {
                AdminExtractionRow(item: item, isBusy: viewModel.isBusy(item))
            }
            .buttonStyle(.plain)
            .contextMenu {
                if item.canEdit {
                    Button("Approve", systemImage: "checkmark.seal") { Task { await viewModel.approve(item) } }
                    Button("Reject", systemImage: "xmark.seal", role: .destructive) { Task { await viewModel.reject(item) } }
                }
            }
        }
    }

    /// Lista già a schermo ma l'ultimo aggiornamento è fallito: una riga sottile con il motivo.
    @ViewBuilder
    private var errorPill: some View {
        if viewModel.hasLoaded, !viewModel.visibleItems.isEmpty, let message = viewModel.loadError {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Button("Retry") { Task { await viewModel.load() } }
                    .font(.footnote.weight(.semibold))
                    .disabled(viewModel.isLoading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .ariaGlass(in: Capsule())
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
        }
    }
}
