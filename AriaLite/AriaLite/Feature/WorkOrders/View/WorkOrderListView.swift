//
//  WorkOrderListView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 19/03/26.
//
import SwiftUI
// MARK: - WorkOrderActionModifier
struct WorkOrderActionModifier: ViewModifier {
    @Binding var workOrderToStart: WorkOrder?
    @Binding var selectedWorkOrder: WorkOrder?
    @Binding var showMaintenanceMode: Bool
    let viewModel: AppViewModel

    @State private var voice = AriaVoiceViewModel()

    private var isAlertPresented: Binding<Bool> {
        Binding(
            get: { workOrderToStart != nil },
            set: { if !$0 { workOrderToStart = nil } }
        )
    }

    func body(content: Content) -> some View {
        content
            .alert(
                workOrderTitle,
                isPresented: isAlertPresented,
                actions: alertActions,
                message: alertMessage
            )
            .fullScreenCover(
                isPresented: $showMaintenanceMode,
                content: maintenanceContent
            )
    }

    // MARK: - Alert

    private var workOrderTitle: String {
        workOrderToStart?.title ?? ""
    }

    @ViewBuilder
    private func alertActions() -> some View {
        Button("Start", action: startWorkOrder)
            .keyboardShortcut(.defaultAction)

        Button("Cancel", role: .cancel) {
            workOrderToStart = nil
        }
    }

    private func alertMessage() -> some View {
        Text("Make sure you are on site before proceeding.")
    }

    private func startWorkOrder() {
        guard let wo = workOrderToStart else { return }
        selectedWorkOrder = wo
        showMaintenanceMode = true
        workOrderToStart = nil
    }

    // MARK: - FullScreen

    @ViewBuilder
    private func maintenanceContent() -> some View {
        if let wo = selectedWorkOrder {
            MaintenanceModeView(workOrder: wo, viewModel: viewModel, voice: voice)
        }
    }
}

// MARK: - View Extension

private extension View {
    func workOrderStartFlow(
        workOrderToStart: Binding<WorkOrder?>,
        selectedWorkOrder: Binding<WorkOrder?>,
        showMaintenanceMode: Binding<Bool>,
        viewModel: AppViewModel
    ) -> some View {
        modifier(
            WorkOrderActionModifier(
                workOrderToStart: workOrderToStart,
                selectedWorkOrder: selectedWorkOrder,
                showMaintenanceMode: showMaintenanceMode,
                viewModel: viewModel
            )
        )
    }
}

// MARK: - Reusable WorkOrder List

struct WorkOrderListContent: View {
    let workOrders: [WorkOrder]
    let viewModel: AppViewModel
    let onTap: (WorkOrder) -> Void
    var isPast: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            ForEach(workOrders) { workOrder in
                Button {
                    onTap(workOrder)
                } label: {
                    WorkOrderRowView(workOrder: workOrder, viewModel: viewModel)
                        .opacity(isPast ? 0.6 : 1)
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - WorkOrderListView

struct WorkOrderListView: View {
    let viewModel: AppViewModel

    @State private var workOrderToStart: WorkOrder?
    @State private var selectedWorkOrder: WorkOrder?
    @State private var showMaintenanceMode = false

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            Group {
                if viewModel.searchText.isEmpty {
                    scheduledList
                } else if viewModel.filteredWorkOrders.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else {
                    ScrollView {
                        WorkOrderListContent(
                            workOrders: viewModel.filteredWorkOrders,
                            viewModel: viewModel,
                            onTap: { workOrderToStart = $0 }
                        )
                        .padding(.vertical, 12)
                    }
                }
            }
            .liteBackground()
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
            }
            .searchable(
                text: $viewModel.searchText,
                prompt: Text("Search tasks...")
            )
        }
        .workOrderStartFlow(
            workOrderToStart: $workOrderToStart,
            selectedWorkOrder: $selectedWorkOrder,
            showMaintenanceMode: $showMaintenanceMode,
            viewModel: viewModel
        )
    }

    // MARK: - Scheduled list (Today + Past)

    private var scheduledList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: - Today
                sectionHeader(
                    title: String(localized: "Today"),
                    subtitle: todaySubtitle,
                    icon: "calendar",
                    color: Color.liteAccent
                )
                .padding(.top, 12)

                if viewModel.todayWorkOrders.isEmpty {
                    emptyState(
                        icon: "tray",
                        message: String(localized: "No tasks for today")
                    )
                } else {
                    WorkOrderListContent(
                        workOrders: viewModel.todayWorkOrders,
                        viewModel: viewModel,
                        onTap: { workOrderToStart = $0 }
                    )
                    .padding(.bottom, 8)
                }

                // MARK: - Past
                if !viewModel.pastWorkOrdersByDay.isEmpty {
                    sectionHeader(
                        title: String(localized: "Past"),
                        subtitle: String(localized: "\(viewModel.pastWorkOrdersByDay.flatMap(\.value).count) archived tasks"),
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

                            WorkOrderListContent(
                                workOrders: item.value,
                                viewModel: viewModel,
                                onTap: { workOrderToStart = $0 },
                                isPast: true
                            )
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
    }

    // MARK: - Helpers

    private var todaySubtitle: String {
        let count = viewModel.todayWorkOrders.count
        return count == 0 ? String(localized: "No scheduled tasks") : String(localized: "\(count) scheduled tasks")
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
