//
//  AdminAgentStudioApprovalsView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Lo storico delle approvazioni, come /agent-studio/approvals della web: i passi fermi ad aspettare una persona
//  e quelli già decisi, con il filtro per stato (in attesa, approvate, rifiutate, scadute, annullate, tutte).
//

import SwiftUI

struct AdminAgentStudioApprovalsView: View {
    @Bindable var viewModel: AdminAgentStudioViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Menu {
                    Picker("Status", selection: $viewModel.approvalFilter) {
                        ForEach(AdminAgentStudioApprovalFilter.allCases) { Text($0.label).tag($0) }
                    }
                } label: {
                    AdminFilterChip(title: "Status", value: viewModel.approvalFilter.label,
                                    isActive: viewModel.approvalFilter != .pending)
                }
                AdminAgentStudioLoadState(
                    hasLoaded: viewModel.approvalsLoaded,
                    isEmpty: viewModel.visibleApprovals.isEmpty,
                    errorMessage: viewModel.approvalsError,
                    failureTitle: "Can't load approvals",
                    emptyTitle: "Nothing to approve",
                    emptyImage: "checkmark.seal",
                    emptyDescription: "Steps that wait for a person's decision show up here.",
                    retry: { await reload() }
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.visibleApprovals) { approval in
                            NavigationLink(value: AdminAgentStudioRoute.approval(id: approval.id)) {
                                AdminAgentStudioListRow(
                                    systemImage: "person.badge.shield.checkmark",
                                    title: approval.displayTitle,
                                    subtitle: viewModel.subtitle(for: approval),
                                    footnote: viewModel.footnote(for: approval),
                                    badge: approval.status.map { AdminAgentStudioBadge(status: $0) }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
            .ariaReadableWidth()
        }
        .liteBackground()
        .navigationTitle("Approvals")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await reload() }
        .task(id: viewModel.approvalsKey) { await viewModel.loadApprovals() }
    }

    private func reload() async {
        if viewModel.approvalFilter == .pending {
            await viewModel.load()
        } else {
            await viewModel.loadApprovals(force: true)
        }
    }
}
