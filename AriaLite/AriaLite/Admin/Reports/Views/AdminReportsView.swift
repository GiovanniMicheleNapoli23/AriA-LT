//
//  AdminReportsView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Reports, come la pagina /reports della web: filtro per stabilimento e quattro parti
//  (panoramica, ordini di lavoro, asset, widget salvati), ognuna con il suo stato. Trascina per aggiornare.
//

import SwiftUI

struct AdminReportsView: View {
    @Bindable var viewModel: AdminReportsViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    AdminReportPlantFilter(viewModel: viewModel)
                    AdminReportOverviewSection(viewModel: viewModel)
                    AdminReportWorkOrdersSection(viewModel: viewModel)
                    AdminReportAssetsSection(viewModel: viewModel)
                    AdminReportWidgetsSection(viewModel: viewModel)
                }
                .padding(20)
                .ariaReadableWidth()
            }
            .refreshable { await viewModel.load() }
            .liteBackground()
            .navigationTitle("Reports")
            .navigationDestination(for: AdminCraftedWidget.self) { widget in
                AdminCraftedWidgetDetailView(viewModel: viewModel.makeWidgetDetail(for: widget),
                                             canDelete: viewModel.canDelete(widget)) {
                    await viewModel.deleteReturningError(widget)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
            }
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
