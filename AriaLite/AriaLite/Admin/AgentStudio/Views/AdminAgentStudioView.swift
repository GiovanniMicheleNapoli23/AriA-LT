//
//  AdminAgentStudioView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Agent Studio: una sola schermata che scorre (cosa richiede attenzione, i workflow, la
//  configurazione), la campanella delle notifiche e la navigazione verso i dettagli.
//

import SwiftUI

struct AdminAgentStudioView: View {
    let viewModel: AdminAgentStudioViewModel

    @State private var path: [AdminAgentStudioRoute] = []
    @State private var showsNotifications = false
    @Environment(\.ariaSetupTour) private var setupTour

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if viewModel.hasLoaded { AdminAgentStudioAttentionSection(viewModel: viewModel) }
                        AdminAgentStudioWorkflowsSection(viewModel: viewModel)
                            .id(TourScrollTarget.workflows)
                            .ariaSetupTourAnchor(.workflows)
                        AdminAgentStudioConfigurationSection()
                            .id(TourScrollTarget.configuration)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                    .ariaReadableWidth()
                }
                // Il giro guidato indica i workflow o una riga della configurazione, in fondo: la porta in vista.
                // Anche quando la lista si carica e sposta tutto.
                .onChange(of: setupTour?.current, initial: true) { _, step in
                    reveal(step, scroll)
                }
                .onChange(of: viewModel.hasLoaded) { _, _ in
                    reveal(setupTour?.current, scroll)
                }
            }
            .refreshable { await viewModel.load() }
            .liteBackground()
            .navigationTitle("Agent Studio")
            .navigationDestination(for: AdminAgentStudioRoute.self) { route in
                destination(for: route)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                ToolbarItem(placement: .topBarTrailing) { notificationsButton }
            }
            .sheet(isPresented: $showsNotifications) {
                AdminAgentStudioNotificationsView(viewModel: viewModel) { route in
                    showsNotifications = false
                    path.append(route)
                }
            }
        }
        // Il giro guidato si fa da parte con una schermata di dettaglio o il foglio delle notifiche aperti.
        .ariaSetupTourAside(!path.isEmpty, source: "agentStudio.path")
        .ariaSetupTourAside(showsNotifications, source: "agentStudio.notifications")
        .task(id: viewModel.loadKey) { await viewModel.load() }
    }

    /// Dove scorrere per mostrare l'elemento di un passo del giro guidato.
    private enum TourScrollTarget: Hashable {
        case workflows, configuration
    }

    private func reveal(_ step: AriaSetupTourStep?, _ scroll: ScrollViewProxy) {
        let target: TourScrollTarget
        switch step {
        case .workflows: target = .workflows
        case .agents, .governance: target = .configuration
        default: return
        }
        withAnimation { scroll.scrollTo(target, anchor: target == .workflows ? .top : .center) }
    }

    @ViewBuilder
    private func destination(for route: AdminAgentStudioRoute) -> some View {
        switch route {
        case .workflow(let id):
            AdminAgentStudioWorkflowDetailView(viewModel: viewModel.makeWorkflowViewModel(id: id))
        case .canvas(let workflowId):
            if let canvas = viewModel.makeCanvasViewModel(workflowId: workflowId) {
                AdminAgentStudioCanvasView(viewModel: canvas)
            } else {
                ContentUnavailableView("Can't load this workflow", systemImage: "exclamationmark.triangle")
            }
        case .run(let workflowId, let runId):
            AdminAgentStudioRunDetailView(viewModel: viewModel.makeRunViewModel(workflowId: workflowId, runId: runId))
        case .approval(let id):
            AdminAgentStudioApprovalDetailView(viewModel: viewModel.makeApprovalViewModel(id: id))
        case .approvals:
            AdminAgentStudioApprovalsView(viewModel: viewModel)
        case .policy:
            AdminAgentStudioPolicyView(viewModel: viewModel)
        case .accuracy:
            AdminAgentStudioAccuracyView(viewModel: viewModel)
        case .prompts:
            AdminAgentStudioPromptsView(viewModel: viewModel.prompts)
        case .prompt(let name):
            AdminAgentStudioPromptEditorView(viewModel: viewModel.prompts.makeEditor(name: name))
        }
    }

    private var notificationsButton: some View {
        Button {
            showsNotifications = true
        } label: {
            Image(systemName: viewModel.unreadCount > 0 ? "bell.badge" : "bell")
                .symbolRenderingMode(.hierarchical)
        }
        .accessibilityLabel(Text("Notifications"))
        .accessibilityValue(Text("\(viewModel.unreadCount) unread"))
    }
}
