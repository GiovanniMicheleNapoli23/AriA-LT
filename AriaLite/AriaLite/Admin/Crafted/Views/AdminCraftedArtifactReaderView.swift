//
//  AdminCraftedArtifactReaderView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Il lettore di un artifact fatto da Crafted: intestazione, poi quello che Aria ha fatto — dal vivo
//  mentre lo crea — in lettura, in modifica a mano o a confronto fra versioni. In alto Modifica e il menu
//  (Cronologia, Rinomina, "Apri la chat"); Aria nel pulsante in basso a destra. Solo la pagina scorre in verticale.
//

import SwiftUI

struct AdminCraftedArtifactReaderView: View {
    @State private var viewModel: AdminCraftedArtifactReaderViewModel

    @Environment(\.openChatSession) private var openChatSession
    @Environment(\.openURL) private var openURL

    init(viewModel: AdminCraftedArtifactReaderViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AdminCraftedArtifactHeader(viewModel: viewModel)
                if viewModel.saveFailed {
                    AdminSectionNotice(text: String(localized: "It could not be saved on this device."), isError: true)
                }
                content
            }
            .padding(20)
            .ariaReadableWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        .liteBackground()
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isEditing)
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .top, spacing: 0) {
            if viewModel.isComparing, let header = viewModel.compareHeader {
                AdminCraftedCompareBar(
                    header: header, onAgainst: { viewModel.setAgainst($0) },
                    onRestore: { viewModel.restore(header.number) }, onClose: { viewModel.closeCompare() }
                )
            }
        }
        // Una volta all'apertura, e di nuovo quando il turno di questa sessione finisce.
        .task(id: viewModel.isGenerating) { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .sensoryFeedback(.success, trigger: viewModel.savedCount)
        .sheet(isPresented: $viewModel.showsHistory) {
            AdminCraftedVersionHistorySheet(entries: viewModel.historyEntries, selected: viewModel.comparedNumber) {
                viewModel.openCompare($0)
            }
        }
        .adminCraftedAria(
            editor: viewModel.ariaEditor, panel: $viewModel.ariaPanel, asksDiscard: $viewModel.showsAriaDiscard,
            choices: viewModel.ariaChoices, summary: viewModel.ariaSummary, showsResume: viewModel.showsAriaResume,
            showsButton: viewModel.canEdit, open: { viewModel.openAria() },
            actions: ariaActions, discardAndOpen: { viewModel.discardEditAndOpenAria() }
        )
        .alert("Rename", isPresented: $viewModel.showsRename) {
            TextField("Title", text: $viewModel.renameText)
            Button("Save") { Task { await viewModel.rename() } }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Discard changes?", isPresented: $viewModel.showsDiscard) {
            Button("Discard", role: .destructive) { viewModel.discard() }
            Button("Keep editing", role: .cancel) {}
        }
    }

    // MARK: Contenuto

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .generating, .loading, .failed:
            AdminCraftedArtifactStateView(phase: viewModel.phase, failureNote: viewModel.failureNote) { viewModel.retry() }
        case .unreadable:
            AdminCraftedArtifactOfflineContent(viewModel: viewModel, actions: actions)
        case .content:
            if viewModel.isEditing {
                AdminCraftedArtifactEditContent(viewModel: viewModel)
            } else if let proposal = viewModel.ariaProposal {
                AdminCraftedArtifactCompareContent(blocks: proposal.blocks)
            } else if viewModel.isComparing {
                AdminCraftedArtifactCompareContent(blocks: viewModel.compareBlocks)
            } else {
                AdminCraftedArtifactReadContent(viewModel: viewModel, actions: actions, openChat: openChat)
            }
        }
    }

    /// Le card mandano alla chat quello che nell'app non ha una pagina, e i link passano da AriaURLPolicy.
    private var actions: AriaArtifactActions {
        AriaArtifactActions(
            ask: { _ in openChat() },
            quick: { _, _, _ in openChat() },
            open: { path in if let url = viewModel.webURL(for: path) { openURL(url) } }
        )
    }

    private func openChat() { openChatSession?(viewModel.sessionId) }

    /// Il pannello di Aria chiama il lettore; "Apri la conversazione" lo nasconde prima di cambiare schermata.
    private var ariaActions: AdminCraftedAriaActions {
        AdminCraftedAriaActions(
            send: { viewModel.sendAria() }, stop: { viewModel.stopAria() }, accept: { viewModel.acceptAria() },
            discard: { viewModel.closeAria() },
            openChat: {
                guard let id = viewModel.ariaSessionId else { return }
                viewModel.hideAria()
                openChatSession?(id)
            },
            hide: { viewModel.hideAria() }
        )
    }

    // MARK: Barra

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if viewModel.isEditing {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { viewModel.requestCancel() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(viewModel.saveTitle) { viewModel.save() }
                    .disabled(!viewModel.isDirty)
            }
        } else if viewModel.artifact != nil {
            if viewModel.canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit", systemImage: "pencil") { viewModel.beginEdit() }
                        .disabled(viewModel.ariaBusy)
                }
            }
            ToolbarItem(placement: .topBarTrailing) { menu }
        }
    }

    private var menu: some View {
        Menu {
            if viewModel.canEdit {
                Button("Version history", systemImage: "clock.arrow.circlepath") { viewModel.openHistory() }
                    .disabled(viewModel.ariaBusy)
            }
            Button("Rename", systemImage: "pencil.line") { viewModel.startRename() }
            Button("Open the chat", systemImage: "bubble.left.and.text.bubble.right") { openChat() }
                .disabled(openChatSession == nil)
        } label: {
            Label("Menu", systemImage: "ellipsis.circle")
        }
    }
}
