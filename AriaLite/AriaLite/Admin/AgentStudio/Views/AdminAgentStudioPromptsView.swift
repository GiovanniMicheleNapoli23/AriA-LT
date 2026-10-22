//
//  AdminAgentStudioPromptsView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I prompt di sistema degli agenti per l'azienda: quali sono personalizzati e quali usano il testo
//  di base. Toccarne uno apre l'editor.
//

import SwiftUI

struct AdminAgentStudioPromptsView: View {
    let viewModel: AdminAgentStudioPromptsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                AdminAgentStudioLoadState(
                    hasLoaded: viewModel.hasLoaded,
                    isEmpty: viewModel.prompts.isEmpty,
                    errorMessage: viewModel.errorMessage,
                    failureTitle: "Can't load agent prompts",
                    emptyTitle: "No agents",
                    emptyImage: "text.bubble",
                    emptyDescription: "This company has no agents with an editable prompt.",
                    retry: { await viewModel.load() }
                ) {
                    Text("\(viewModel.overriddenCount) of \(viewModel.prompts.count) customised")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.top, 4)
                    ForEach(viewModel.prompts) { prompt in
                        NavigationLink(value: AdminAgentStudioRoute.prompt(name: prompt.name)) {
                            AdminAgentStudioListRow(
                                systemImage: "brain",
                                title: prompt.name,
                                subtitle: prompt.description,
                                badge: prompt.isOverridden
                                    ? AdminAgentStudioBadge(text: String(localized: "Custom"), tone: .active)
                                    : AdminAgentStudioBadge(text: String(localized: "Default"), tone: .neutral)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
            .ariaReadableWidth()
        }
        .liteBackground()
        .navigationTitle("Agent prompts")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.load() }
        .task(id: viewModel.loadKey) { await viewModel.load() }
    }
}
