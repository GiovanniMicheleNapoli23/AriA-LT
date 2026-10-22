//
//  AdminReasoningSessionView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una sessione, come /settings/sessions/{sessionId} della web: numeri della sessione e timeline
//  dei turni, dal primo all'ultimo. Il menu in alto rinomina o elimina la sessione.
//

import SwiftUI

struct AdminReasoningSessionView: View {
    @State private var viewModel: AdminReasoningSessionViewModel

    @Environment(\.dismiss) private var dismiss

    init(viewModel: AdminReasoningSessionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(viewModel.title)
                    .font(.title2.weight(.bold))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if !viewModel.stats.isEmpty { AdminReasoningStatGrid(stats: viewModel.stats) }
                infoCard
                timeline
            }
            .padding(20)
            .ariaReadableWidth()
        }
        .liteBackground()
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Actions", systemImage: "ellipsis.circle") {
                    Button("Rename", systemImage: "pencil") { viewModel.editor.beginRename(viewModel.session) }
                    Button("Delete", systemImage: "trash", role: .destructive) { viewModel.editor.beginDelete(viewModel.session) }
                }
                .disabled(viewModel.editor.isWorking)
            }
        }
        .modifier(AdminReasoningSessionEditorModifier(editor: viewModel.editor))
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .onChange(of: viewModel.isDeleted) { _, deleted in
            if deleted { dismiss() }
        }
    }

    private var infoCard: some View {
        AdminCard(title: "Session", systemImage: "info.circle") {
            let fields = viewModel.fields
            VStack(spacing: 0) {
                ForEach(fields) { field in
                    AdminFieldRow(field: field, showsDivider: field != fields.last)
                }
            }
        }
    }

    // MARK: Timeline

    @ViewBuilder
    private var timeline: some View {
        AdminCard(title: "Turns", systemImage: "list.bullet.indent") {
            if !viewModel.hasLoaded {
                if let message = viewModel.errorMessage {
                    VStack(alignment: .leading, spacing: 10) {
                        AdminSectionNotice(text: message, isError: true)
                        Button("Retry") { Task { await viewModel.load() } }
                            .font(.subheadline.weight(.semibold))
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
                }
            } else if viewModel.turns.isEmpty {
                AdminSectionNotice(text: String(localized: "No turn traces recorded for this session."),
                                   systemImage: "text.bubble")
            } else {
                turnList
            }
        }
    }

    private var turnList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let message = viewModel.errorMessage {
                AdminSectionNotice(text: message, isError: true).padding(.bottom, 10)
            }
            if let note = viewModel.truncationNote {
                AdminSectionNotice(text: note, systemImage: "info.circle").padding(.bottom, 10)
            }
            let turns = viewModel.timeline
            ForEach(turns) { turn in
                NavigationLink(value: turn) {
                    AdminReasoningTurnRow(turn: turn, isLast: turn.id == turns.last?.id)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
