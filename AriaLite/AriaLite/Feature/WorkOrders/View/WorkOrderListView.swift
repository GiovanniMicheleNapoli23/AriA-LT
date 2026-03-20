//
//  WorkOrderListView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 19/03/26.
//
import SwiftUI

// MARK: - Shared WorkOrder Start Modifier

private struct WorkOrderStartModifier: ViewModifier {
    @Binding var workOrderToStart: WorkOrder?
    @Binding var selectedWorkOrder: WorkOrder?
    @Binding var showMaintenanceMode: Bool
    let viewModel: AppViewModel

    func body(content: Content) -> some View {
        content
            .alert(
                workOrderToStart?.title ?? "",
                isPresented: .init(
                    get: { workOrderToStart != nil },
                    set: { if !$0 { workOrderToStart = nil } }
                )
            ) {
                Button("Avvia") {
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
    }
}

private extension View {
    func workOrderStartFlow(
        workOrderToStart: Binding<WorkOrder?>,
        selectedWorkOrder: Binding<WorkOrder?>,
        showMaintenanceMode: Binding<Bool>,
        viewModel: AppViewModel
    ) -> some View {
        modifier(WorkOrderStartModifier(
            workOrderToStart: workOrderToStart,
            selectedWorkOrder: selectedWorkOrder,
            showMaintenanceMode: showMaintenanceMode,
            viewModel: viewModel
        ))
    }
}


// MARK: - WorkOrderListView

struct WorkOrderListView: View {
    let viewModel: AppViewModel
    let user: User

    @State private var workOrderToStart: WorkOrder?
    @State private var selectedWorkOrder: WorkOrder?
    @State private var showMaintenanceMode = false
    @State private var showSettingsSheet = false

    var body: some View {
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

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // MARK: - Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text(greetingText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(user.name)
                                .font(.title2.bold())
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 20)

                        // MARK: - Oggi
                        sectionHeader(
                            title: "Oggi",
                            subtitle: todaySubtitle,
                            icon: "calendar",
                            color: Color.liteAccent
                        )

                        if viewModel.todayWorkOrders.isEmpty {
                            emptyState(
                                icon: "tray",
                                message: "Nessun work order per oggi"
                            )
                        } else {
                            VStack(spacing: 8) {
                                ForEach(viewModel.todayWorkOrders) { workOrder in
                                    Button { workOrderToStart = workOrder } label: {
                                        WorkOrderRowView(workOrder: workOrder, viewModel: viewModel)
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            .padding(.bottom, 8)
                        }

                        // MARK: - Passati
                        if !viewModel.pastWorkOrdersByDay.isEmpty {
                            sectionHeader(
                                title: "Passati",
                                subtitle: "\(viewModel.pastWorkOrdersByDay.flatMap(\.value).count) work order archiviati",
                                icon: "clock.arrow.circlepath",
                                color: .secondary
                            )
                            .padding(.top, 12)

                            VStack(spacing: 0) {
                                ForEach(viewModel.pastWorkOrdersByDay, id: \.key) { item in
                                    Text(item.key)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                        .textCase(.uppercase)
                                        .padding(.horizontal, 20)
                                        .padding(.top, 16)
                                        .padding(.bottom, 6)

                                    VStack(spacing: 8) {
                                        ForEach(item.value) { workOrder in
                                            Button { workOrderToStart = workOrder } label: {
                                                WorkOrderRowView(workOrder: workOrder, viewModel: viewModel)
                                                    .opacity(0.6)
                                            }
                                            .padding(.horizontal, 20)
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettingsSheet = true } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .tint(Color.liteAccent)
                }
            }
        }
        .workOrderStartFlow(
            workOrderToStart: $workOrderToStart,
            selectedWorkOrder: $selectedWorkOrder,
            showMaintenanceMode: $showMaintenanceMode,
            viewModel: viewModel
        )
        .sheet(isPresented: $showSettingsSheet) {
            SettingsSheet(user: user, viewModel: viewModel)
        }
    }

    // MARK: - Helpers

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12:  return "Buongiorno,"
        case 12..<18: return "Buon pomeriggio,"
        default:      return "Buonasera,"
        }
    }

    private var todaySubtitle: String {
        let count = viewModel.todayWorkOrders.count
        return count == 0 ? "Nessuna attività" : "\(count) attività in programma"
    }

    @ViewBuilder
    private func sectionHeader(
        title: String,
        subtitle: String,
        icon: String,
        color: Color
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.bold())
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func emptyState(icon: String, message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .padding(.bottom, 8)
    }
}


// MARK: - WorkOrderSearchView

struct WorkOrderSearchView: View {
    let viewModel: AppViewModel
    let user: User

    @State private var workOrderToStart: WorkOrder?
    @State private var selectedWorkOrder: WorkOrder?
    @State private var showMaintenanceMode = false

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

                Group {
                    if viewModel.filteredWorkOrders.isEmpty {
                        ContentUnavailableView.search(text: viewModel.searchText)
                    } else {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(viewModel.filteredWorkOrders) { workOrder in
                                    Button { workOrderToStart = workOrder } label: {
                                        WorkOrderRowView(workOrder: workOrder, viewModel: viewModel)
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            .padding(.vertical, 12)
                        }
                    }
                }
            }
            .navigationTitle("Cerca")
            .navigationBarTitleDisplayMode(.inline)
        }
        .searchable(
            text: $viewModel.searchText,
            placement: .automatic,
            prompt: "Cerca work order..."
        )
        .workOrderStartFlow(
            workOrderToStart: $workOrderToStart,
            selectedWorkOrder: $selectedWorkOrder,
            showMaintenanceMode: $showMaintenanceMode,
            viewModel: viewModel
        )
    }
}

