//
//  AdminCraftedLibraryList.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  La lista di Crafted: filtro per categoria, avvisi, righe raggruppate per mese e, quando non c'è
//  niente da mostrare, lo stato vuoto. Una List semplice (scorre solo in verticale) che si aggiorna trascinando.
//

import SwiftUI

struct AdminCraftedLibraryList: View {
    @Bindable var viewModel: AdminCraftedViewModel
    let library: AdminCraftedLibrary

    @Environment(\.openChatSession) private var openChatSession

    var body: some View {
        List {
            if !library.chips.isEmpty {
                AdminCraftedCategoryFilter(chips: library.chips, total: library.searchedCount,
                                           selected: library.selectedCategory) { category in
                    withAnimation(.snappy) { viewModel.category = category }
                }
                .craftedListRow(top: 4, bottom: 8)
            }
            notes
            if let state = library.emptyState {
                AdminCraftedEmptyView(state: state, retry: { await viewModel.load() },
                                      create: { viewModel.openComposer() }, canCreate: viewModel.canCompose)
                    .craftedListRow()
            } else {
                ForEach(library.groups) { group in
                    if let label = group.label {
                        AdminCraftedMonthHeader(label: label)
                            .craftedListRow(top: 14, bottom: 2)
                    }
                    ForEach(group.items) { item in row(item) }
                }
                Text("\(library.visibleCount) artifacts")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)
                    .craftedListRow(top: 12, bottom: 16)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.load() }
        .ariaReadableWidth()
        .liteBackground()
    }

    // MARK: Avvisi

    @ViewBuilder
    private var notes: some View {
        switch library.note {
        case .restricted?:
            Text("Intervention reports are visible to owners and admins.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .craftedListRow(top: 4, bottom: 4)
        case .failed(let message)?:
            AdminCraftedErrorPill(message: message, isLoading: viewModel.isLoading) { await viewModel.load() }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        case nil:
            EmptyView()
        }
        if let warning = viewModel.storageWarning {
            Text(warning)
                .font(.footnote)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .craftedListRow(top: 4, bottom: 4)
        }
    }

    // MARK: Riga

    private func row(_ item: AdminCraftedItem) -> some View {
        Button {
            viewModel.open(item)
        } label: {
            AdminCraftedItemRow(title: item.title, info: viewModel.rowInfo(for: item))
        }
        .buttonStyle(.plain)
        .craftedListRow(top: 4, bottom: 4)
        .contextMenu {
            Button("Open the chat", systemImage: "bubble.left.and.bubble.right") { openChatSession?(item.sessionId) }
                .disabled(openChatSession == nil)
            if let artifact = viewModel.artifact(of: item) {
                Button("Delete", systemImage: "trash", role: .destructive) { viewModel.delete(artifact) }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if let artifact = viewModel.artifact(of: item) {
                Button("Delete", systemImage: "trash", role: .destructive) { viewModel.delete(artifact) }
            }
        }
    }
}

private extension View {
    /// Una riga della lista senza separatore né sfondo di riga, coi margini laterali di Crafted.
    func craftedListRow(top: CGFloat = 0, bottom: CGFloat = 0) -> some View {
        listRowInsets(EdgeInsets(top: top, leading: 20, bottom: bottom, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}
