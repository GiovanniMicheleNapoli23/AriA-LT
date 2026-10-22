//
//  AdminDocumentChunksView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il testo estratto di un documento, chunk per chunk, con ricerca e "Load more".
//  Sola lettura: il testo si cambia ricaricando il documento.
//

import SwiftUI

struct AdminDocumentChunksView: View {
    @State private var viewModel: AdminDocumentChunksViewModel

    init(viewModel: AdminDocumentChunksViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .ariaReadableWidth()
        }
        .liteBackground()
        .navigationTitle("Extracted text")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, prompt: Text("Search the loaded text"))
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        if !viewModel.hasLoaded {
            if let message = viewModel.errorMessage {
                ContentUnavailableView("Can't load the text", systemImage: "exclamationmark.triangle",
                                       description: Text(message))
                    .padding(.top, 40)
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
            }
        } else if viewModel.chunks.isEmpty {
            ContentUnavailableView("No text yet", systemImage: "text.quote",
                                   description: Text("Chunks appear when indexing finishes."))
                .padding(.top, 40)
        } else if viewModel.visibleChunks.isEmpty {
            ContentUnavailableView.search(text: viewModel.searchText)
        } else {
            Text(viewModel.subtitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            ForEach(viewModel.visibleChunks) { chunk in
                AdminDocumentChunkRow(chunk: chunk)
            }
            if let message = viewModel.errorMessage {
                AdminSectionNotice(text: message, isError: true)
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
        }
    }
}
