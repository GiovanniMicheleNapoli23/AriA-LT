//
//  WorkOrderListView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 19/03/26.
//
import SwiftUI
import Foundation

struct WorkOrderListView: View {
    let viewModel: AppViewModel
    let user: User
    @State private var workOrderToStart: WorkOrder?
    @State private var selectedWorkOrder: WorkOrder?
    @State private var showMaintenanceMode = false
    @State private var showSettingsSheet = false

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            ZStack {
                Color.liteBackground.ignoresSafeArea()
                RadialGradient(
                    colors: [Color.liteAccent.opacity(0.07), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 420
                )
                .ignoresSafeArea()

                List(viewModel.filteredWorkOrders) { workOrder in
                    Button {
                        workOrderToStart = workOrder
                    } label: {
                        WorkOrderRowView(workOrder: workOrder, viewModel: viewModel)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .navigationTitle("Work Orders")
                .navigationSubtitle(user.name)
                .searchable(
                    text: $viewModel.searchText,
                    placement: .toolbar,
                    prompt: "Cerca work order..."
                )
                .searchToolbarBehavior(.minimize)

                .toolbar {
                    ToolbarSpacer(.flexible, placement: .bottomBar)
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showSettingsSheet = true
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .tint(Color.liteAccent)
                    }
                }
            }
        }
        .preferredColorScheme(.light)
        .alert(
            "\(workOrderToStart?.title ?? "")",
            isPresented: .init(
                get: { workOrderToStart != nil },
                set: { if !$0 { workOrderToStart = nil } }
            )
        ) {
            Button("Avvia", role: .confirm) {
                if let wo = workOrderToStart {
                    selectedWorkOrder = wo
                    showMaintenanceMode = true
                }
                workOrderToStart = nil
            }
            .keyboardShortcut(.defaultAction)
            Button("Annulla", role: .cancel) {
                workOrderToStart = nil
            }
        } message: {
            Text("Assicurati di essere sul posto prima di procedere.")
        }
        .fullScreenCover(isPresented: $showMaintenanceMode) {
            if let wo = selectedWorkOrder {
                MaintenanceModeView(workOrder: wo, viewModel: viewModel)
            }
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsSheet(user: user, viewModel: viewModel)
        }
    }
}

