//
//  AdminAgentStudioPolicyTab.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda "Policy", come /agent-studio/policy della web: limiti e regole dei workflow (con "Edit"),
//  chi approva cosa per livello di rischio, le liste ammesse/vietate e il link ai prompt degli agenti.
//

import SwiftUI

struct AdminAgentStudioPolicyTab: View {
    let viewModel: AdminAgentStudioViewModel
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AdminAgentStudioLoadState(
                hasLoaded: viewModel.hasLoaded,
                isEmpty: viewModel.policy == nil,
                errorMessage: viewModel.policyError,
                failureTitle: "Can't load the policy",
                emptyTitle: "No policy",
                emptyImage: "shield",
                emptyDescription: "This company runs its workflows on the default rules.",
                retry: { await viewModel.load() }
            ) {
                rulesCard
                if let tiers = viewModel.policy?.tiers, !tiers.isEmpty { tiersCard(tiers) }
                if !viewModel.policyLists.isEmpty { listsCard }
            }
            promptsLink
        }
    }

    private var rulesCard: some View {
        AdminCard(title: "Rules", systemImage: "shield.lefthalf.filled") {
            Button("Edit", action: onEdit)
                .font(.subheadline.weight(.semibold))
                .tint(Color.liteAccent)
        } content: {
            rows(viewModel.policyFields)
        }
    }

    private func tiersCard(_ tiers: [AdminAgentStudioPolicyTier]) -> some View {
        AdminCard(title: "Approvals by risk", systemImage: "person.badge.shield.checkmark") {
            VStack(alignment: .leading, spacing: 8) {
                rows(tiers.map { AdminAssetField(title: $0.name, value: viewModel.summary(for: $0)) })
                Text("Reads (R0) never wait for anyone. The matrix is edited on the web.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var listsCard: some View {
        AdminCard(title: "Lists", systemImage: "list.bullet.rectangle") {
            rows(viewModel.policyLists)
        }
    }

    private func rows(_ fields: [AdminAssetField]) -> some View {
        VStack(spacing: 0) {
            ForEach(fields) { field in
                AdminFieldRow(field: field, showsDivider: field != fields.last)
            }
        }
    }

    private var promptsLink: some View {
        NavigationLink(value: AdminAgentStudioRoute.prompts) {
            AdminAgentStudioListRow(
                systemImage: "text.bubble",
                title: String(localized: "Agent prompts"),
                subtitle: String(localized: "The system prompt of each agent for this company.")
            )
        }
        .buttonStyle(.plain)
    }
}
