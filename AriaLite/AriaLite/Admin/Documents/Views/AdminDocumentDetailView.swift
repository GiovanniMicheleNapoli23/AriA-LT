//
//  AdminDocumentDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un documento: intestazione, stato delle pipeline (con "Stop" mentre lavorano),
//  descrizione e tag, scheda tecnica, run e il testo estratto. Il menu in alto rilancia o cancella.
//

import SwiftUI

struct AdminDocumentDetailView: View {
    @State private var viewModel: AdminDocumentDetailViewModel
    @State private var showsChunks = false
    @Environment(\.dismiss) private var dismiss

    init(viewModel: AdminDocumentDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AdminDocumentHeader(document: viewModel.document)
                if let message = viewModel.documentError {
                    AdminSectionNotice(text: message, isError: true)
                }
                AdminDocumentPipelineCard(viewModel: viewModel)
                if viewModel.document.description != nil || !viewModel.document.tags.isEmpty { aboutCard }
                detailsCard
                AdminDocumentRunsCard(viewModel: viewModel)
                chunksCard
            }
            .padding(20)
            .ariaReadableWidth()
        }
        .liteBackground()
        .navigationTitle(viewModel.document.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showsChunks) {
            AdminDocumentChunksView(viewModel: viewModel.makeChunksViewModel())
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { actionsMenu }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .task(id: viewModel.pollKey) { await viewModel.pollWhileWorking() }
        .onChange(of: viewModel.didDelete) { _, deleted in
            if deleted { dismiss() }
        }
        .confirmationDialog(Text(viewModel.pendingAction?.title ?? ""), isPresented: $viewModel.showsConfirmation,
                            titleVisibility: .visible, presenting: viewModel.pendingAction) { action in
            Button(action.confirmLabel, role: action.isDestructive ? .destructive : nil) {
                Task { await viewModel.perform(action) }
            }
            if action == .delete {
                Button("Delete with extracted data", role: .destructive) {
                    Task { await viewModel.perform(action, removingExtractedData: true) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { action in
            Text(action.message)
        }
        .alert(Text(viewModel.failedAction?.failureTitle ?? ""), isPresented: $viewModel.showsActionError) {
            Button("OK") {}
        } message: {
            Text(viewModel.actionError ?? "")
        }
    }

    private var actionsMenu: some View {
        Menu("Actions", systemImage: "ellipsis.circle") {
            Button("Index again", systemImage: "arrow.clockwise") { viewModel.ask(.ingest) }
                .disabled(!viewModel.canRerun)
            Button("Run extraction", systemImage: "wand.and.sparkles") { viewModel.ask(.extract) }
                .disabled(!viewModel.canRerun)
            if viewModel.canCancel {
                Button("Stop processing", systemImage: "stop.circle") { viewModel.ask(.cancel) }
            }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) { viewModel.ask(.delete) }
                .disabled(!viewModel.canDelete)
        }
        .disabled(viewModel.isPerforming)
    }

    // MARK: Schede

    private var aboutCard: some View {
        AdminCard(title: "About", systemImage: "text.alignleft") {
            VStack(alignment: .leading, spacing: 10) {
                if let description = viewModel.document.description {
                    Text(description)
                        .font(.subheadline)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !viewModel.document.tags.isEmpty {
                    Text(viewModel.document.tags.map { "#\($0)" }.joined(separator: "  "))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.liteAccent)
                        .fixedSize(horizontal: false, vertical: true)
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

    private var chunksCard: some View {
        AdminCard(title: "Extracted text", systemImage: "text.quote") {
            VStack(alignment: .leading, spacing: 10) {
                Text("The pieces of text Aria searches when it answers.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    showsChunks = true
                } label: {
                    HStack {
                        if let count = viewModel.chunkCount {
                            Text("View \(count) chunks")
                        } else {
                            Text("View chunks")
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                    .font(.subheadline.weight(.semibold))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.liteAccent)
            }
        }
    }
}
