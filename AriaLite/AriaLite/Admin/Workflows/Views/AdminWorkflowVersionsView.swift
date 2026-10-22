//
//  AdminWorkflowVersionsView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il foglio delle versioni pubblicate di un flusso, la più recente per prima. "Restore" riporta il
//  flusso al grafo di quella versione, dopo conferma. Errori e conferma stanno qui: sotto un foglio
//  gli avvisi del dettaglio non si vedrebbero.
//

import SwiftUI

struct AdminWorkflowVersionsView: View {
    let viewModel: AdminWorkflowDetailViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            content
                .liteBackground()
                .navigationTitle("Versions")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }.tint(Color.liteAccent)
                    }
                }
        }
        .task { await viewModel.loadVersions() }
        .confirmationDialog(viewModel.pendingConfirmation?.title ?? "",
                            isPresented: $viewModel.showsRestoreConfirmation,
                            titleVisibility: .visible, presenting: viewModel.pendingConfirmation) { confirmation in
            Button(confirmation.actionTitle) {
                if case .restore(let version) = confirmation {
                    Task { if await viewModel.restore(version) { dismiss() } }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { confirmation in
            Text(confirmation.message)
        }
        .alert("Couldn't restore the version", isPresented: $viewModel.showsVersionsError) {
            Button("OK") {}
        } message: {
            Text(viewModel.versionsError ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        if !viewModel.versionsLoaded {
            if viewModel.isLoadingVersions {
                ProgressView()
            } else {
                VStack(spacing: 14) {
                    ContentUnavailableView("Can't load the versions", systemImage: "exclamationmark.triangle")
                    Button {
                        Task { await viewModel.loadVersions() }
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                    .ariaGlassButtonStyle()
                }
            }
        } else if viewModel.versions.isEmpty {
            ContentUnavailableView("No versions yet", systemImage: "clock.arrow.circlepath",
                                   description: Text("Publish the flow to save its first version."))
        } else {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(viewModel.versions) { version in
                        HStack(spacing: 8) {
                            AdminWorkflowVersionRow(version: version, isCurrent: viewModel.isCurrent(version))
                            if !viewModel.isCurrent(version) {
                                Button("Restore", systemImage: "arrow.uturn.backward") {
                                    viewModel.askToRestore(version)
                                }
                                    .buttonStyle(.bordered)
                                    .tint(Color.liteAccent)
                                    .disabled(viewModel.isBusy)
                            }
                        }
                        .padding(14)
                        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(20)
                .ariaReadableWidth()
            }
        }
    }
}
