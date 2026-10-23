//
//  AdminAgentStudioRunDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un run: stato (seguito dal vivo finché non finisce), contatori, riassunto, blocchi,
//  verdetto di ogni nodo, registro degli eventi e scheda. "Cancel run" in alto finché è vivo.
//

import SwiftUI

struct AdminAgentStudioRunDetailView: View {
    @State private var viewModel: AdminAgentStudioRunViewModel

    @ScaledMetric(relativeTo: .body) private var tileWidth: CGFloat = 120

    init(viewModel: AdminAgentStudioRunViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let message = viewModel.runError {
                    AdminSectionNotice(text: message, isError: true)
                }
                if !viewModel.counters.isEmpty { counters }
                if let run = viewModel.run {
                    if let narrative = run.narrative { narrativeCard(narrative) }
                    if !run.blockers.isEmpty { blockersCard(run) }
                    if !run.steps.isEmpty { stepsCard(run) }
                }
                eventsCard
                detailsCard
            }
            .padding(20)
            .ariaReadableWidth()
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
        .refreshable { await viewModel.load() }
        .task {
            await viewModel.load()
            await viewModel.follow()
        }
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(viewModel.title)
                    .font(.title3.weight(.bold))
                Spacer(minLength: 8)
                if let status = viewModel.status { AdminAgentStudioBadge(status: status) }
            }
            if viewModel.isActive {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Group {
                        if viewModel.canReadRecord { Text("Following live") } else { Text("In progress") }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            if viewModel.run?.refused == true {
                AdminSectionNotice(text: String(localized: "The policy refused this run."), isError: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    private var counters: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: tileWidth), spacing: 10)], spacing: 10) {
            ForEach(viewModel.counters, id: \.status) { counter in
                AdminStatTile(title: counter.title, value: "\(counter.value)",
                              tint: AdminAgentStudioStatus.tone(for: counter.status).color)
            }
        }
    }

    private func narrativeCard(_ narrative: String) -> some View {
        AdminCard(title: "Summary", systemImage: "text.alignleft") {
            Text(narrative)
                .font(.subheadline)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func blockersCard(_ run: AdminAgentStudioRun) -> some View {
        AdminCard(title: "Blockers", systemImage: "hand.raised") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(run.blockers, id: \.self) { blocker in
                    Label {
                        Text(blocker).fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.octagon").foregroundStyle(.red)
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private func stepsCard(_ run: AdminAgentStudioRun) -> some View {
        AdminCard(title: "Steps", systemImage: "list.number") {
            VStack(spacing: 0) {
                ForEach(run.steps) { step in
                    AdminAgentStudioRunStepRow(step: step, showsDivider: step.id != run.steps.last?.id)
                }
                if run.truncated {
                    AdminSectionNotice(text: String(localized: "The server kept only part of this run's steps."))
                        .padding(.top, 8)
                }
            }
        }
    }

    private var eventsCard: some View {
        AdminCard(title: "Event log", systemImage: "list.bullet.rectangle") {
            VStack(alignment: .leading, spacing: 8) {
                if let message = viewModel.eventsError {
                    AdminSectionNotice(text: message, isError: true)
                }
                if viewModel.hasLoadedEvents {
                    if viewModel.events.isEmpty {
                        AdminSectionNotice(text: String(localized: "No events recorded."))
                    } else {
                        VStack(spacing: 0) {
                            ForEach(viewModel.events) { event in
                                AdminAgentStudioEventRow(event: event, showsDivider: event.id != viewModel.events.last?.id)
                            }
                        }
                    }
                } else if viewModel.isLoadingEvents {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Group {
                            if viewModel.eventsWaitUntilFinished { Text("Waiting for the run to finish…") } else { Text("Loading…") }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } else {
                    Button {
                        Task { await viewModel.loadEvents() }
                    } label: {
                        Label("Load event log", systemImage: "arrow.down.circle")
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(Color.liteAccent)
                    if viewModel.eventsWaitUntilFinished {
                        Text("While the run is going, the log arrives when it finishes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
}
