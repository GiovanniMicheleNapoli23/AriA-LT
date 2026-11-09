//
//  AdminAgentStudioWorkflowDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un workflow: intestazione con attiva/disattiva, "Run it" (modalità + Start), il flusso
//  "How it works", gli ultimi run e i dettagli. Il canvas si apre dalla barra in alto.
//  Niente testo selezionabile né controlli UIKit (a parte il Toggle). Il grafo è in sola lettura.
//

import SwiftUI

struct AdminAgentStudioWorkflowDetailView: View {
    @State private var viewModel: AdminAgentStudioWorkflowViewModel

    init(viewModel: AdminAgentStudioWorkflowViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 20) {
                if viewModel.workflow == nil {
                    loadingOrError
                } else {
                    AdminAgentStudioWorkflowHeader(
                        title: viewModel.title,
                        description: viewModel.workflow?.description,
                        statusLine: viewModel.statusLine,
                        isEnabledNow: viewModel.isEnabled,
                        errorMessage: viewModel.workflowError,
                        isEnabled: $viewModel.isEnabled,
                        isToggling: viewModel.isTogglingEnabled
                    )
                    AdminAgentStudioRunModeSection(
                        selection: viewModel.selectedMode,
                        startLabel: viewModel.startLabel,
                        isRealRun: viewModel.isRealRun,
                        canStart: viewModel.canStart,
                        onSelect: { viewModel.selectedMode = $0 },
                        onStart: { Task { await viewModel.choose(viewModel.selectedMode) } }
                    )
                    AdminAgentStudioHowItWorksSection(steps: viewModel.flowSteps)
                    AdminAgentStudioRecentRunsSection(viewModel: viewModel)
                    AdminAgentStudioDetailsSection(fields: viewModel.fields)
                }
            }
            .padding(20)
            .ariaReadableWidth()
        }
        .liteBackground()
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.workflow != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: AdminAgentStudioRoute.canvas(workflowId: viewModel.workflowId)) {
                        Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                    }
                    .accessibilityLabel("Open canvas")
                }
            }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .navigationDestination(isPresented: $viewModel.showsLaunchedRun) {
            if let run = viewModel.launchedRun { AdminAgentStudioRunDetailView(viewModel: run) }
        }
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
}
