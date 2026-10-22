//
//  AdminAgentStudioView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Agent Studio, come le pagine /agent-studio della web: quattro schede (workflow, approvazioni,
//  run attivi, policy), la campanella delle notifiche e la navigazione verso i dettagli.
//

import SwiftUI

struct AdminAgentStudioView: View {
    @Bindable var viewModel: AdminAgentStudioViewModel

    @State private var path: [AdminAgentStudioRoute] = []
    @State private var showsNotifications = false
    @State private var policyForm: AdminAgentStudioPolicyFormViewModel?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Section", selection: $viewModel.tab) {
                        ForEach(AdminAgentStudioTab.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    tabContent
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
            .sheet(item: $policyForm) { form in
                AdminAgentStudioPolicyFormView(viewModel: form) { viewModel.policySaved($0) }
            }
        }
        .task(id: viewModel.loadKey) { await viewModel.load() }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.tab {
        case .workflows:
            AdminAgentStudioWorkflowsTab(viewModel: viewModel)
        case .approvals:
            AdminAgentStudioApprovalsTab(viewModel: viewModel)
        case .runs:
            AdminAgentStudioRunsTab(viewModel: viewModel)
        case .policy:
            AdminAgentStudioPolicyTab(viewModel: viewModel) {
                policyForm = viewModel.makePolicyFormViewModel()
            }
        }
    }

    @ViewBuilder
    private func destination(for route: AdminAgentStudioRoute) -> some View {
        switch route {
        case .workflow(let id):
            AdminAgentStudioWorkflowDetailView(viewModel: viewModel.makeWorkflowViewModel(id: id))
        case .run(let workflowId, let runId):
            AdminAgentStudioRunDetailView(viewModel: viewModel.makeRunViewModel(workflowId: workflowId, runId: runId))
        case .approval(let id):
            AdminAgentStudioApprovalDetailView(viewModel: viewModel.makeApprovalViewModel(id: id))
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
