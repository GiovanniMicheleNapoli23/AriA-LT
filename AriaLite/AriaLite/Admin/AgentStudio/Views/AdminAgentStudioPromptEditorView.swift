//
//  AdminAgentStudioPromptEditorView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'editor del prompt di sistema di un agente: niente ScrollView attorno, il TextEditor scorre da solo e
//  prende tutta l'altezza che resta tra l'intestazione e la barra in fondo. Avvisi del server, prompt di base e
//  "Reset to default" (con conferma) stanno nel menu e nei fogli, per non rubargli spazio.
//

import SwiftUI

struct AdminAgentStudioPromptEditorView: View {
    @State private var viewModel: AdminAgentStudioPromptEditorViewModel
    @FocusState private var editorFocused: Bool

    init(viewModel: AdminAgentStudioPromptEditorViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            if let prompt = viewModel.prompt {
                content(prompt)
            } else {
                ContentUnavailableView("Agent not found", systemImage: "text.bubble",
                                       description: Text("Go back and pull to refresh the list."))
            }
        }
        .liteBackground()
        .navigationTitle(viewModel.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if viewModel.isBusy {
                    ProgressView()
                } else {
                    Button("Save") {
                        editorFocused = false
                        Task { await viewModel.save() }
                    }
                    .disabled(!viewModel.canSave)
                }
                if viewModel.hasMenuActions { moreMenu }
            }
        }
        .sheet(isPresented: $viewModel.showsBasePrompt) {
            AdminAgentStudioPromptBaseSheet(text: viewModel.prompt?.basePrompt ?? "")
        }
        .sheet(isPresented: $viewModel.showsWarnings) {
            AdminAgentStudioPromptWarningsSheet(warnings: viewModel.warnings)
                .presentationDetents([.medium, .large])
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

    private func content(_ prompt: AdminAgentStudioAgentPrompt) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                AdminAgentStudioPromptHeader(prompt: prompt)
                if !viewModel.warnings.isEmpty {
                    AdminAgentStudioPromptWarningsBanner(warnings: viewModel.warnings) {
                        viewModel.showsWarnings = true
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            editor
            AdminAgentStudioPromptFooter(
                characterCount: viewModel.characterCount,
                savedLabel: viewModel.savedLabel,
                hasChanges: viewModel.hasChanges,
                onDiscard: { viewModel.discardChanges() }
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .ariaReadableWidth()
    }

    private var editor: some View {
        TextEditor(text: $viewModel.text)
            .font(.callout.monospaced())
            .focused($editorFocused)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 16)
    }

    private var moreMenu: some View {
        Menu {
            if viewModel.canViewBase {
                Button {
                    editorFocused = false
                    viewModel.showsBasePrompt = true
                } label: {
                    Label("View base prompt", systemImage: "doc.text")
                }
            }
            if viewModel.canReset {
                Button(role: .destructive) {
                    viewModel.showsResetConfirmation = true
                } label: {
                    Label("Reset to default", systemImage: "arrow.uturn.backward")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel(Text("More"))
    }
}
