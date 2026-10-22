//
//  AdminLLMUsageSessionsSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le sessioni di chat più recenti con il loro consumo; Stop per quelle ancora attive.
//

import SwiftUI

struct AdminLLMUsageSessionsSection: View {
    let viewModel: AdminLLMUsageViewModel

    var body: some View {
        AdminCard(title: "Recent sessions", systemImage: "bubble.left.and.text.bubble.right", accessory: {
            if viewModel.isLoadingSessions, !viewModel.sessions.isEmpty { ProgressView() }
        }, content: {
            if let failure = viewModel.sessionsFailure {
                AdminLLMUsageNote(message: failure) { Task { await viewModel.loadSessions() } }
            }
            if viewModel.sessions.isEmpty {
                if viewModel.isLoadingSessions {
                    ProgressView().frame(maxWidth: .infinity)
                } else if viewModel.sessionsFailure == nil {
                    Text("No sessions yet.").font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                ForEach(viewModel.sessions) { session in
                    AdminLLMUsageSessionRow(
                        session: session,
                        canStop: viewModel.canStop(session),
                        isStopping: viewModel.stoppingSessionId == session.id,
                        onStop: { viewModel.requestStop(session) }
                    )
                    if session.id != viewModel.sessions.last?.id { Divider() }
                }
            }
        })
    }
}
