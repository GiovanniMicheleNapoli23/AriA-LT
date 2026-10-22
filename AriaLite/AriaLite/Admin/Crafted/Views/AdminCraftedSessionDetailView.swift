//
//  AdminCraftedSessionDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una sessione conclusa: verdetto e fatti, passi della procedura, cose imparate, report Word da
//  condividere e la conversazione in sola lettura. "Rename" in alto cambia il titolo della sessione.
//

import SwiftUI

struct AdminCraftedSessionDetailView: View {
    @State private var viewModel: AdminCraftedSessionViewModel

    init(viewModel: AdminCraftedSessionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AdminCraftedSessionHeader(viewModel: viewModel)
                reportCard
                if !viewModel.steps.isEmpty { stepsCard }
                if !viewModel.learned.isEmpty { learnedCard }
                conversation
            }
            .padding(20)
            .ariaReadableWidth()
        }
        .liteBackground()
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Rename", systemImage: "pencil") { viewModel.startRename() }
            }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .alert("Rename session", isPresented: $viewModel.showsRename) {
            TextField("Title", text: $viewModel.renameText)
            Button("Save") { Task { await viewModel.rename() } }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Something went wrong", isPresented: $viewModel.showsActionError) {
            Button("OK") {}
        } message: {
            Text(viewModel.actionError ?? "")
        }
    }

    // MARK: Report

    private var reportCard: some View {
        AdminCard(title: "Intervention report", systemImage: "doc.richtext") {
            if let report = viewModel.report {
                ShareLink(item: report.url) {
                    Label("Share \(report.filename)", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .ariaGlassButtonStyle()
            } else {
                Button {
                    Task { await viewModel.prepareReport() }
                } label: {
                    HStack {
                        Label("Prepare Word report", systemImage: "arrow.down.doc")
                        if viewModel.preparingReport { ProgressView() }
                    }
                    .frame(maxWidth: .infinity)
                }
                .ariaGlassButtonStyle()
                .disabled(viewModel.preparingReport)
            }
        }
    }

    // MARK: Passi e cose imparate

    private var stepsCard: some View {
        AdminCard(title: "Procedure steps", systemImage: "list.number") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(viewModel.steps.enumerated()), id: \.offset) { _, step in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline) {
                            Text([step.label, step.title].compactMap { $0 }.joined(separator: " · "))
                                .font(.subheadline.weight(.medium))
                            Spacer(minLength: 8)
                            if let outcome = step.outcome {
                                Text(outcome.replacingOccurrences(of: "_", with: " "))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let report = step.operatorReport, !report.isEmpty {
                            Text(report)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var learnedCard: some View {
        AdminCard(title: "What Aria learned", systemImage: "brain") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(viewModel.learned) { fact in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.content)
                            .font(.subheadline)
                            .textSelection(.enabled)
                        if let status = fact.status {
                            Text(status.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: Conversazione

    private var conversation: some View {
        AdminCard(title: "Conversation", systemImage: "bubble.left.and.text.bubble.right") {
            VStack(alignment: .leading, spacing: 14) {
                if let message = viewModel.errorMessage {
                    AdminSectionNotice(text: message, isError: true)
                }
                if !viewModel.hasLoaded {
                    if viewModel.errorMessage == nil {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
                    }
                } else if viewModel.visibleMessages.isEmpty {
                    AdminSectionNotice(text: String(localized: "No messages in this session."),
                                       systemImage: "bubble.left")
                } else {
                    ForEach(viewModel.visibleMessages) { message in
                        AdminCraftedMessageRow(message: message, viewModel: viewModel)
                    }
                }
            }
        }
    }
}
