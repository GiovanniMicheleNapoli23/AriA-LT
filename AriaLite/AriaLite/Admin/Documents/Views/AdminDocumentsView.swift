//
//  AdminDocumentsView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La libreria documenti, come la pagina /knowledge della web: filtri (stato, stabilimento), ricerca,
//  riepilogo, lista con stato di elaborazione aggiornato da solo, "+" per caricare da Files.
//  Il dettaglio è in AdminDocumentDetailView.
//

import SwiftUI

struct AdminDocumentsView: View {
    @Bindable var viewModel: AdminDocumentsViewModel

    @State private var path: [AdminDocument] = []
    @State private var upload: AdminDocumentUploadViewModel?

    var body: some View {
        NavigationStack(path: $path) {
            // Una lista di card: scorre solo in verticale.
            List {
                Group {
                    AdminDocumentsFilterBar(viewModel: viewModel)
                    if viewModel.hasLoaded, let message = viewModel.errorMessage {
                        AdminDocumentErrorPill(message: message, isDisabled: viewModel.isLoading) {
                            Task { await viewModel.load() }
                        }
                        .padding(.horizontal, 20)
                    }
                    content
                }
                .ariaReadableWidth()
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable { await viewModel.load() }
            .liteBackground()
            .navigationTitle("Documents")
            .navigationDestination(for: AdminDocument.self) { document in
                AdminDocumentDetailView(viewModel: viewModel.makeDetailViewModel(for: document))
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Upload documents", systemImage: "plus") { upload = viewModel.makeUploadViewModel() }
                        .disabled(!viewModel.canUpload)
                }
            }
            .searchable(text: $viewModel.searchText, prompt: Text("Title, file name, tag"))
            .sheet(item: $upload) { model in
                AdminDocumentUploadView(viewModel: model) {
                    Task { await viewModel.uploadFinished() }
                }
            }
            .alert("Delete this document?", isPresented: $viewModel.showsDeleteConfirmation,
                   presenting: viewModel.documentToDelete) { document in
                Button("Delete document", role: .destructive) {
                    Task { await viewModel.delete(document, removingExtractedData: false) }
                }
                Button("Delete with extracted data", role: .destructive) {
                    Task { await viewModel.delete(document, removingExtractedData: true) }
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text(AdminDocumentAction.delete.message)
            }
            .alert("Couldn't delete the document", isPresented: $viewModel.showsActionError) {
                Button("OK") {}
            } message: {
                Text(viewModel.actionError ?? "")
            }
        }
        .task(id: viewModel.loadKey) { await viewModel.load() }
        .task(id: viewModel.pollKey) { await viewModel.pollWhileProcessing() }
    }

    // MARK: Contenuto

    @ViewBuilder
    private var content: some View {
        if !viewModel.hasLoaded {
            if let message = viewModel.errorMessage {
                // La lista non è mai arrivata: non si dice "nessun documento", si dice perché.
                VStack(spacing: 14) {
                    ContentUnavailableView("Can't load documents", systemImage: "exclamationmark.triangle",
                                           description: Text(message))
                    Button {
                        Task { await viewModel.load() }
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                    .ariaGlassButtonStyle()
                }
                .padding(.top, 40)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            }
        } else if viewModel.documents.isEmpty {
            ContentUnavailableView {
                Label("No documents", systemImage: "doc.text.magnifyingglass")
            } description: {
                Text("Upload manuals, procedures and datasheets: Aria uses them to answer and to propose assets and spare parts.")
            } actions: {
                Button("Upload documents") { upload = viewModel.makeUploadViewModel() }
                    .disabled(!viewModel.canUpload)
            }
            .padding(.top, 40)
        } else {
            AdminDocumentsSummary(viewModel: viewModel)
                .padding(.horizontal, 20)
            if viewModel.visibleDocuments.isEmpty {
                if viewModel.isSearching {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else {
                    ContentUnavailableView("No documents", systemImage: "doc.text",
                                           description: Text("No documents match these filters."))
                        .padding(.top, 20)
                }
            } else {
                list
            }
        }
    }

    @ViewBuilder
    private var list: some View {
        Text(viewModel.subtitle)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 20)
            .padding(.top, 4)
        ForEach(viewModel.visibleDocuments) { document in
            Button { path.append(document) } label: {
                AdminDocumentRow(document: document)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Delete", systemImage: "trash", role: .destructive) { viewModel.askDelete(document) }
                    .disabled(document.statusGroup == .deleting)
            }
            .padding(.horizontal, 20)
        }
        if viewModel.canLoadMore {
            Button {
                Task { await viewModel.loadMore() }
            } label: {
                if viewModel.isLoadingMore {
                    ProgressView()
                } else {
                    Label("Load more", systemImage: "arrow.down.circle")
                }
            }
            .ariaGlassButtonStyle()
            .disabled(viewModel.isLoadingMore)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
        if let updated = viewModel.lastUpdated {
            Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 24)
        }
    }
}
