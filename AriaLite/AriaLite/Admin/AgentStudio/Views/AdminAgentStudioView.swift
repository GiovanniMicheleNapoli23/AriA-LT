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

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if viewModel.hasLoaded { AdminAgentStudioAttentionSection(viewModel: viewModel) }
                    AdminAgentStudioWorkflowsSection(viewModel: viewModel)
                    AdminAgentStudioConfigurationSection()
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 24)
                .ariaReadableWidth()
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
        .task(id: viewModel.loadKey) { await viewModel.load() }
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
