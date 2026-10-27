//
//  AdminAgentStudioPolicyView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  La policy, come /agent-studio/policy della web: limiti e regole dei workflow (con "Edit" e il suo form),
//  chi approva cosa per livello di rischio e le liste ammesse/vietate.
//

import SwiftUI

struct AdminAgentStudioPolicyView: View {
    let viewModel: AdminAgentStudioViewModel

    @State private var policyForm: AdminAgentStudioPolicyFormViewModel?

    var body: some View {
        ScrollView {
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
            }
            .padding(20)
            .ariaReadableWidth()
        }
        .liteBackground()
        .navigationTitle("Policy")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.load() }
        .sheet(item: $policyForm) { form in
            AdminAgentStudioPolicyFormView(viewModel: form) { viewModel.policySaved($0) }
        }
    }

    private var rulesCard: some View {
        AdminCard(title: "Rules", systemImage: "shield.lefthalf.filled") {
            Button("Edit") { policyForm = viewModel.makePolicyFormViewModel() }
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
}
