//
//  AdminAgentStudioWorkflowDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un workflow: attiva/disattiva, avvio (controllo, simulazione, run reale) con l'esito,
//  i passi in sola lettura, la scheda e lo storico dei run. Il grafo si modifica sulla web.
//

import SwiftUI

struct AdminAgentStudioWorkflowDetailView: View {
    @State private var viewModel: AdminAgentStudioWorkflowViewModel

    init(viewModel: AdminAgentStudioWorkflowViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.workflow == nil {
                    loadingOrError
                } else {
                    headerCard
                    AdminAgentStudioRunLauncherCard(viewModel: viewModel)
                    stepsCard
                    detailsCard
                    runsCard
                }
            }
            .padding(20)
            .ariaReadableWidth()
        }
        .liteBackground()
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .alert("Agent Studio", isPresented: $viewModel.showsActionError) {
            Button("OK") {}
        } message: {
            Text(viewModel.actionError ?? "")
        }
        .alert("Run this workflow for real?", isPresented: $viewModel.showsRunConfirmation) {
            Button("Run for real", role: .destructive) { Task { await viewModel.start(.run) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Actions go to the connected systems. Steps that need approval will wait for a person.")
        }
    }

    @ViewBuilder
    private var loadingOrError: some View {
        if let message = viewModel.workflowError {
            VStack(spacing: 14) {
                ContentUnavailableView("Can't load this workflow", systemImage: "exclamationmark.triangle",
                                       description: Text(message))
                Button {
                    Task { await viewModel.load() }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .ariaGlassButtonStyle()
            }
            .padding(.top, 40)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.title)
                .font(.title3.weight(.bold))
                .textSelection(.enabled)
            if let description = viewModel.workflow?.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let message = viewModel.workflowError {
                AdminSectionNotice(text: message, isError: true)
            }
            Toggle(isOn: $viewModel.isEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enabled").font(.subheadline.weight(.semibold))
                    Text("Enabled workflows run on their trigger.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(Color.liteAccent)
            .disabled(viewModel.isTogglingEnabled)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    private var stepsCard: some View {
        AdminCard(title: "Steps", systemImage: "list.number") {
            let steps = viewModel.steps
            if steps.isEmpty {
                AdminSectionNotice(text: String(localized: "This workflow has no steps yet."))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        AdminAgentStudioStepRow(index: index + 1, step: step, showsDivider: index < steps.count - 1)
                    }
                }
            }
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

    private var runsCard: some View {
        AdminCard(title: "Runs", systemImage: "clock.arrow.circlepath") {
            VStack(alignment: .leading, spacing: 8) {
                if let message = viewModel.runsError {
                    AdminSectionNotice(text: message, isError: true)
                } else if viewModel.sortedRuns.isEmpty {
                    AdminSectionNotice(text: String(localized: "No runs yet."), systemImage: "clock")
                }
                ForEach(viewModel.sortedRuns.prefix(30)) { run in
                    NavigationLink(value: AdminAgentStudioRoute.run(workflowId: viewModel.workflowId, runId: run.id)) {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.subtitle(for: run))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                if let footnote = viewModel.footnote(for: run) {
                                    Text(footnote).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 8)
                            if let status = run.status { AdminAgentStudioBadge(status: status) }
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
