//
//  AdminAgentStudioAttentionSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  "Needs attention": le approvazioni che aspettano una persona e i run in corso. Se non c'è niente,
//  una sola riga tranquilla al posto della sezione.
//

import SwiftUI

struct AdminAgentStudioAttentionSection: View {
    let viewModel: AdminAgentStudioViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.needsAttentionIsEmpty {
                if viewModel.attentionErrors.isEmpty {
                    quietLine
                } else {
                    notices
                }
            } else {
                AdminAgentStudioSectionHeader(title: "Needs attention")
                notices
                ForEach(viewModel.attentionApprovals) { approval in
                    NavigationLink(value: AdminAgentStudioRoute.approval(id: approval.id)) {
                        AdminAgentStudioListRow(
                            systemImage: "person.badge.shield.checkmark",
                            title: approval.displayTitle,
                            subtitle: viewModel.subtitle(for: approval),
                            footnote: viewModel.footnote(for: approval),
                            badge: AdminAgentStudioBadge(text: String(localized: "Needs approval"), tone: .warning),
                            iconTint: .orange
                        )
                    }
                    .buttonStyle(.plain)
                }
                ForEach(viewModel.activeRuns) { run in
                    NavigationLink(value: AdminAgentStudioRoute.run(workflowId: run.workflowId, runId: run.id)) {
                        AdminAgentStudioListRow(
                            systemImage: "bolt.horizontal.circle",
                            title: run.workflowName ?? run.id,
                            subtitle: viewModel.subtitle(for: run),
                            footnote: viewModel.footnote(for: run),
                            badge: run.status.map { AdminAgentStudioBadge(status: $0) },
                            iconTint: .blue
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var quietLine: some View {
        Label {
            Text("Nothing needs you right now")
        } icon: {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private var notices: some View {
        ForEach(viewModel.attentionErrors, id: \.self) { message in
            AdminSectionNotice(text: message, isError: true)
        }
    }
}
