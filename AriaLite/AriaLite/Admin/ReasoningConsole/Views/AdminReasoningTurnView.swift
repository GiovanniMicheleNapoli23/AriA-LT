//
//  AdminReasoningTurnView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un turno: domanda, numeri, nodi eseguiti (cascata con tempi ed errori), attribution della risposta
//  e le fasi della trace, ognuna chiusa finché non serve. Pensata per leggersi su telefono.
//

import SwiftUI

struct AdminReasoningTurnView: View {
    @State private var viewModel: AdminReasoningTurnViewModel

    init(viewModel: AdminReasoningTurnViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                question
                if !viewModel.stats.isEmpty { AdminReasoningStatGrid(stats: viewModel.stats) }
                detailsCard
                AdminReasoningNodesCard(viewModel: viewModel)
                AdminReasoningAttributionCard(viewModel: viewModel)
                phases
            }
            .padding(20)
            .ariaReadableWidth()
        }
        .liteBackground()
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
    }

    private var question: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Question")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(AdminReasoningFormat.trimmed(viewModel.summary.question) ?? String(localized: "No question recorded"))
                .font(.headline)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var detailsCard: some View {
        AdminCard(title: "Details", systemImage: "info.circle") {
            let fields = viewModel.fields
            VStack(spacing: 0) {
                ForEach(fields) { field in
                    AdminFieldRow(field: field, showsDivider: field != fields.last)
                }
            }
        }
    }

    /// Le fasi della trace, solo quando la trace è arrivata (altrimenti lo dice già la card dei nodi).
    @ViewBuilder
    private var phases: some View {
        if !viewModel.phases.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Trace")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.top, 4)
                ForEach(viewModel.phases) { phase in
                    AdminReasoningPhaseCard(phase: phase)
                }
            }
        }
    }
}
