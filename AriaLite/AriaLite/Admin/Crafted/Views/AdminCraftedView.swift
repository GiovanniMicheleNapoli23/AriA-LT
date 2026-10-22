//
//  AdminCraftedView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Crafted, come la pagina /crafted della web: in alto si sceglie fra i widget salvati e le
//  sessioni concluse; filtri, ricerca e trascina per aggiornare. I dettagli sono in schermate a parte.
//

import SwiftUI

struct AdminCraftedView: View {
    @Bindable var viewModel: AdminCraftedViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Show", selection: $viewModel.tab) {
                        ForEach(AdminCraftedTab.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    AdminCraftedFilterBar(viewModel: viewModel)
                    switch viewModel.tab {
                    case .widgets: AdminCraftedWidgetsSection(viewModel: viewModel)
                    case .sessions: AdminCraftedSessionsSection(viewModel: viewModel)
                    }
                    if let updated = viewModel.lastUpdated {
                        Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
                .ariaReadableWidth()
            }
            .refreshable { await viewModel.load() }
            .liteBackground()
            .navigationTitle("Crafted")
            .navigationDestination(for: AdminCraftedWidget.self) { widget in
                AdminCraftedWidgetDetailView(viewModel: viewModel.makeWidgetDetail(for: widget),
                                             canDelete: viewModel.canDelete(widget)) {
                    await viewModel.deleteReturningError(widget)
                }
            }
            .navigationDestination(for: AdminCraftedSessionReview.self) { review in
                AdminCraftedSessionDetailView(viewModel: viewModel.makeSessionDetail(for: review))
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
            }
            .searchable(text: $viewModel.searchText, prompt: Text("Search title, type or alarm"))
            .confirmationDialog("Delete this widget?", isPresented: $viewModel.showsDeleteConfirmation,
                                titleVisibility: .visible, presenting: viewModel.widgetToDelete) { widget in
                Button("Delete", role: .destructive) { Task { await viewModel.delete(widget) } }
                Button("Cancel", role: .cancel) {}
            } message: { widget in
                Text("“\(widget.displayTitle)” will be removed from Crafted. The data it shows isn't touched.")
            }
            .alert("Couldn't delete the widget", isPresented: $viewModel.showsActionError) {
                Button("OK") {}
            } message: {
                Text(viewModel.actionError ?? "")
            }
        }
        .task(id: viewModel.loadKey) { await viewModel.load() }
    }
}
