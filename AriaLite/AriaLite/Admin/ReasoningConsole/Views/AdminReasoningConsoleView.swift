//
//  AdminReasoningConsoleView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Reasoning console, come la pagina /settings/sessions della web: le sessioni con l'agente,
//  ricerca, trascina per aggiornare; tieni premuto per rinominare o eliminare. Una sessione apre la
//  timeline dei turni (AdminReasoningSessionView), un turno la sua trace (AdminReasoningTurnView).
//

import SwiftUI

struct AdminReasoningConsoleView: View {
    @Bindable var viewModel: AdminReasoningConsoleViewModel

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    errorPill
                    content
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
                .ariaReadableWidth()
            }
            .refreshable { await viewModel.load() }
            .liteBackground()
            .navigationTitle("Reasoning console")
            .navigationDestination(for: AriaSessionSummary.self) { session in
                AdminReasoningSessionView(viewModel: viewModel.makeSessionViewModel(for: session))
            }
            .navigationDestination(for: AdminReasoningTurnSummary.self) { turn in
                AdminReasoningTurnView(viewModel: viewModel.makeTurnViewModel(for: turn))
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
            }
            .searchable(text: $viewModel.searchText, prompt: Text("Title or session ID"))
            .modifier(AdminReasoningSessionEditorModifier(editor: viewModel.editor))
        }
        .task(id: viewModel.loadKey) { await viewModel.load() }
    }

    // MARK: Contenuto

    @ViewBuilder
    private var content: some View {
        if !viewModel.hasLoaded {
            if let message = viewModel.errorMessage {
                VStack(spacing: 14) {
                    ContentUnavailableView("Can't load sessions", systemImage: "exclamationmark.triangle",
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
        } else if viewModel.visibleSessions.isEmpty {
            if viewModel.isSearching {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else {
                ContentUnavailableView("No sessions", systemImage: "terminal",
                                       description: Text("Conversations with Aria appear here with the reasoning behind every answer."))
                    .padding(.top, 40)
            }
        } else {
            list
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.subtitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)
                .padding(.top, 4)
            ForEach(viewModel.visibleSessions) { session in
                NavigationLink(value: session) {
                    AdminReasoningSessionRow(session: session)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Rename", systemImage: "pencil") { viewModel.editor.beginRename(session) }
                    Button("Delete", systemImage: "trash", role: .destructive) { viewModel.editor.beginDelete(session) }
                }
                .padding(.horizontal, 20)
            }
            if viewModel.canLoadMore {
                Button {
                    Task { await viewModel.loadMore() }
                } label: {
                    if viewModel.isLoadingMore {
                        ProgressView()
                    } else {
                        Label("Load older sessions", systemImage: "arrow.down.circle")
                    }
                }
                .ariaGlassButtonStyle()
                .disabled(viewModel.isLoadingMore)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
            if let updated = viewModel.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
            }
        }
    }

    /// Lista già a schermo ma l'ultimo aggiornamento è fallito: una riga sottile con il motivo.
    @ViewBuilder
    private var errorPill: some View {
        if viewModel.hasLoaded, let message = viewModel.errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Button("Retry") { Task { await viewModel.load() } }
                    .font(.footnote.weight(.semibold))
                    .disabled(viewModel.isLoading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .ariaGlass(in: Capsule())
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
        }
    }
}
