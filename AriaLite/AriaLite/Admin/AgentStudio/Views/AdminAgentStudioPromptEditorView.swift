//
//  AdminAgentStudioPromptEditorView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'editor del prompt di sistema di un agente: testo modificabile, avvisi del server dopo il salvataggio,
//  il prompt di base in sola lettura e "Reset to default" (con conferma) per togliere la personalizzazione.
//

import SwiftUI

struct AdminAgentStudioPromptEditorView: View {
    @State private var viewModel: AdminAgentStudioPromptEditorViewModel
    @FocusState private var editorFocused: Bool
    @State private var showsBasePrompt = false

    @ScaledMetric(relativeTo: .body) private var editorHeight: CGFloat = 280

    init(viewModel: AdminAgentStudioPromptEditorViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let prompt = viewModel.prompt {
                    header(prompt)
                    editorCard
                    if !viewModel.warnings.isEmpty { warningsCard }
                    if prompt.isOverridden { baseCard(prompt) }
                } else {
                    ContentUnavailableView("Agent not found", systemImage: "text.bubble",
                                           description: Text("Go back and pull to refresh the list."))
                        .padding(.top, 40)
                }
            }
            .padding(20)
            .ariaReadableWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        .liteBackground()
        .navigationTitle(viewModel.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Button("Save") {
                        editorFocused = false
                        Task { await viewModel.save() }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
        }
        .alert("Reset to the default prompt?", isPresented: $viewModel.showsResetConfirmation) {
            Button("Reset to default", role: .destructive) { Task { await viewModel.resetToBase() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The custom text for this company is removed. The agent goes back to its base prompt.")
        }
        .alert("Agent prompt", isPresented: $viewModel.showsActionError) {
            Button("OK") {}
        } message: {
            Text(viewModel.actionError ?? "")
        }
    }

    private func header(_ prompt: AdminAgentStudioAgentPrompt) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(prompt.name).font(.title3.weight(.bold))
                Spacer(minLength: 8)
                if prompt.isOverridden {
                    AdminAgentStudioBadge(text: String(localized: "Custom"), tone: .active)
                } else {
                    AdminAgentStudioBadge(text: String(localized: "Default"), tone: .neutral)
                }
            }
            if let description = prompt.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    private var editorCard: some View {
        AdminCard(title: "Prompt", systemImage: "text.bubble") {
            if viewModel.hasChanges {
                Button("Discard") { viewModel.discardChanges() }
                    .font(.subheadline)
                    .tint(.secondary)
            }
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $viewModel.text)
                    .font(.callout.monospaced())
                    .focused($editorFocused)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: editorHeight)
                    .padding(8)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                HStack {
                    Text(viewModel.characterCount)
                    Spacer(minLength: 8)
                    if let saved = viewModel.savedAt {
                        Text("Saved \(saved.formatted(date: .omitted, time: .shortened))")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
                if viewModel.canReset {
                    Button(role: .destructive) {
                        viewModel.showsResetConfirmation = true
                    } label: {
                        if viewModel.isResetting {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Reset to default", systemImage: "arrow.uturn.backward")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    private var warningsCard: some View {
        AdminCard(title: "Warnings", systemImage: "exclamationmark.triangle") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(viewModel.warnings, id: \.self) { warning in
                    AdminSectionNotice(text: warning, isError: true)
                }
            }
        }
    }

    private func baseCard(_ prompt: AdminAgentStudioAgentPrompt) -> some View {
        AdminCard(title: "Base prompt", systemImage: "doc.text") {
            DisclosureGroup(isExpanded: $showsBasePrompt) {
                Text(prompt.basePrompt)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
            } label: {
                Text("The text this agent uses without customisation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .tint(Color.liteAccent)
        }
    }
}
