//
//  AdminAgentStudioRunDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il run visto dal vivo, un passo alla volta: intestazione con avanzamento, controlli iniziali, approvazioni,
//  cronologia che si segue da sola, riassunto, file, dettagli e registro tecnico. "Cancel run" finché è vivo.
//

import SwiftUI

struct AdminAgentStudioRunDetailView: View {
    @State private var viewModel: AdminAgentStudioRunViewModel

    /// Passi aperti dalla persona: solo presentazione.
    @State private var expandedSteps: Set<String> = []
    /// La persona ha toccato lo scorrimento: la cronologia non si porta più da sola al passo in corso.
    @State private var userScrolled = false

    init(viewModel: AdminAgentStudioRunViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AdminAgentStudioRunHeaderCard(viewModel: viewModel)
                    notices
                    if viewModel.isConnecting { connecting }
                    if viewModel.hasPreflight {
                        AdminAgentStudioPreflightCard(checks: viewModel.preflightChecks,
                                                      startsExpanded: viewModel.preflightFailed)
                    }
                    if viewModel.isRefused {
                        AdminAgentStudioRefusalCard(reasons: viewModel.refusalReasons)
                    }
                    ForEach(viewModel.pendingApprovals) { approval in
                        AdminAgentStudioApprovalWaitCard(approval: approval)
                    }
                    if viewModel.showsTimeline { timeline }
                    if let narrative = viewModel.narrativeText { summary(narrative) }
                    if !viewModel.artifacts.isEmpty { artifacts }
                    AdminAgentStudioRunDetailsCard(fields: viewModel.fields, counters: viewModel.counters,
                                                   isActive: viewModel.isActive)
                    AdminAgentStudioRunLogCard(events: viewModel.logEvents)
                }
                .padding(20)
                .ariaReadableWidth()
            }
            .onScrollPhaseChange { _, phase in
                if phase == .interacting { userScrolled = true }
            }
            .onChange(of: viewModel.focusRowId) { _, id in
                guard viewModel.isActive, !userScrolled, let id else { return }
                withAnimation(.snappy) { proxy.scrollTo(id, anchor: .center) }
            }
        }
        .liteBackground()
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.isActive {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel run", role: .destructive) { viewModel.showsCancelConfirmation = true }
                        .disabled(!viewModel.canCancel)
                }
            }
        }
        .task { await viewModel.run() }
        .alert("Cancel this run?", isPresented: $viewModel.showsCancelConfirmation) {
            Button("Cancel run", role: .destructive) { Task { await viewModel.cancel() } }
            Button("Keep running", role: .cancel) {}
        } message: {
            Text("A running run stops within a step. A paused one closes and its approvals are withdrawn.")
        }
        .alert("Agent Studio", isPresented: $viewModel.showsActionError) {
            Button("OK") {}
        } message: {
            Text(viewModel.actionError ?? "")
        }
    }

    // MARK: Pezzi

    @ViewBuilder
    private var notices: some View {
        if let message = viewModel.notice {
            AdminSectionNotice(text: message, systemImage: "info.circle")
        }
        if let message = viewModel.runError {
            AdminSectionNotice(text: message, isError: true)
        }
        if let message = viewModel.liveErrorMessage {
            AdminSectionNotice(text: message, isError: true)
        }
    }

    private var connecting: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Connecting to the run…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .accessibilityElement(children: .combine)
    }

    private var timeline: some View {
        let rows = viewModel.rows
        return AdminCard(title: "Steps", systemImage: "list.number") {
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    AdminAgentStudioLiveStepView(row: row, isLast: row.id == rows.last?.id,
                                                 isExpanded: expandedSteps.contains(row.id)) {
                        toggle(row.id)
                    }
                }
            }
        }
    }

    private func summary(_ narrative: String) -> some View {
        AdminCard(title: "Summary", systemImage: "text.alignleft") {
            Text(narrative)
                .font(.subheadline)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var artifacts: some View {
        AdminCard(title: "Artifacts", systemImage: "doc.on.doc") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(viewModel.artifacts) { artifact in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "doc")
                            .font(.subheadline)
                            .foregroundStyle(Color.liteAccent)
                        Text(artifact.name)
                            .font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Text(artifact.kind)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func toggle(_ id: String) {
        withAnimation(.snappy) {
            if !expandedSteps.insert(id).inserted { expandedSteps.remove(id) }
        }
    }
}
