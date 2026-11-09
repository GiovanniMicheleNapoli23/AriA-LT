//
//  AdminCraftedView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  La sezione Crafted, come la pagina /crafted della web: tutto quello che Aria ha prodotto in una lista, con
//  ricerca e ordine; "+" apre il composer; un tocco apre il lettore. L'Annulla dopo un'eliminazione sta in basso.
//

import SwiftUI

struct AdminCraftedView: View {
    @Bindable var viewModel: AdminCraftedViewModel

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            AdminCraftedLibraryList(viewModel: viewModel, library: viewModel.library)
                .navigationTitle("Crafted")
                .navigationDestination(for: AdminCraftedItem.self) { item in
                    AdminCraftedReaderDestination(item: item, viewModel: viewModel)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Menu {
                            Picker("Sort", selection: $viewModel.sort) {
                                ForEach(AdminCraftedSort.allCases) { Text($0.label).tag($0) }
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                        }
                        Button("New artifact", systemImage: "plus") { viewModel.openComposer() }
                            .disabled(!viewModel.canCompose)
                    }
                }
                .searchable(text: $viewModel.searchText, prompt: Text("Search artifacts"))
                .sheet(item: $viewModel.composer) { composer in
                    AdminCraftedComposerView(viewModel: composer)
                }
                .overlay(alignment: .bottom) {
                    if viewModel.lastRemoved != nil {
                        AdminCraftedUndoBanner { viewModel.undoDelete() }
                            .padding(.bottom, 16)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.snappy, value: viewModel.lastRemoved != nil)
        }
        .task(id: viewModel.loadKey) { await viewModel.load() }
    }
}
