//
//  AdminUserSessionsSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Le sessioni aperte della persona (§5.5, solo titolari): icona per client, "App" o "Browser", il dispositivo,
//  "Signed in … · Used …" e "End" (anche con lo scorrimento). "End all sessions" solo con due o più sessioni.
//

import SwiftUI

struct AdminUserSessionsSection: View {
    let viewModel: AdminUserDetailViewModel

    var body: some View {
        if viewModel.controls.sessions {
            Section {
                if !viewModel.sessionsLoaded {
                    if viewModel.sessionsFailed {
                        Text(verbatim: AdminUsersFailure.generic)
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                } else if viewModel.sessions.isEmpty {
                    Text("No open sessions.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.sessions) { session in
                        row(session)
                    }
                    if viewModel.canEndAll {
                        Button("End all sessions", role: .destructive) { viewModel.askEndAll() }
                            .disabled(viewModel.isWorking)
                    }
                }
            } header: {
                Text("Sessions")
            }
        }
    }

    private func row(_ session: AdminUserSession) -> some View {
        HStack(spacing: 12) {
            Image(systemName: session.systemImage)
                .foregroundStyle(.secondary)
                .frame(minWidth: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: session.clientLabel)
                if !session.device.isEmpty {
                    Text(verbatim: session.device)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let times = viewModel.timesText(session) {
                    Text(verbatim: times)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Button("End") { viewModel.askEnd(session) }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.isWorking)
        }
        .swipeActions(edge: .trailing) {
            Button("End", role: .destructive) { viewModel.askEnd(session) }
                .disabled(viewModel.isWorking)
        }
    }
}
