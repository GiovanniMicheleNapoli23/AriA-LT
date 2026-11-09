//
//  AdminConnectorToolsCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I tool che il connettore espone ad Aria, nei tre gruppi della web: eseguiti da soli, con conferma,
//  non disponibili. Ogni gruppo si apre a parte: un server può averne decine.
//

import SwiftUI

struct AdminConnectorToolsCard: View {
    let viewModel: AdminConnectorDetailViewModel

    var body: some View {
        AdminCard(title: "Exposed tools", systemImage: "hammer") {
            if let count = viewModel.tools?.toolCount, count > 0 {
                Text("\(count)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        } content: {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if let tools = viewModel.tools, !tools.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                if let note = viewModel.toolsSourceNote {
                    AdminSectionNotice(text: note, systemImage: "info.circle")
                }
                ForEach(AdminConnectorToolGroup.allCases) { group in
                    let items = viewModel.tools(in: group)
                    if !items.isEmpty {
                        DisclosureGroup {
                            VStack(spacing: 0) {
                                ForEach(items) { tool in
                                    AdminConnectorToolRow(tool: tool)
                                    if tool != items.last { Divider() }
                                }
                            }
                        } label: {
                            Label("\(group.title) (\(items.count))", systemImage: group.systemImage)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                        .tint(Color.liteAccent)
                        .padding(.vertical, 4)
                    }
                }
            }
        } else if let message = viewModel.toolsError {
            AdminSectionNotice(text: message, isError: true)
        } else if viewModel.hasLoadedTools {
            AdminSectionNotice(text: viewModel.toolsSourceNote ?? String(localized: "No tools exposed yet."),
                               systemImage: "hammer")
        } else {
            ProgressView().frame(maxWidth: .infinity)
        }
    }
}
