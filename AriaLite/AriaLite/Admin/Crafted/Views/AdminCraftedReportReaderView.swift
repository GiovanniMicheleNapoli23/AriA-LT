//
//  AdminCraftedReportReaderView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Il lettore di un rapporto d'intervento: intestazione, lingua e zoom, e il documento disegnato come
//  una pagina bianca. Si scorre solo in verticale; in modifica si tocca un paragrafo per cambiarlo e
//  si salva come versione nuova. Condivisione, anteprima dell'originale e cronologia nel menu; Aria nel
//  pulsante in basso a destra.
//

import QuickLook
import SwiftUI

struct AdminCraftedReportReaderView: View {
    @State private var viewModel: AdminCraftedReportReaderViewModel

    @Environment(\.openChatSession) private var openChatSession

    init(viewModel: AdminCraftedReportReaderViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                AdminCraftedReportHeader(viewModel: viewModel)
                if viewModel.saveFailed {
                    AdminSectionNotice(text: String(localized: "It could not be saved on this device."), isError: true)
                }
                controls
                content
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .ariaReadableWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        .liteBackground()
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isEditing)
        .toolbar { toolbar }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let header = viewModel.compareHeader, viewModel.comparedNumber != nil {
                AdminCraftedCompareBar(
                    header: header, onAgainst: { viewModel.setAgainst($0) },
                    onRestore: { viewModel.restore(header.number) }, onClose: { viewModel.closeCompare() }
                )
            }
        }
        .task { await viewModel.load() }
        .sensoryFeedback(.success, trigger: viewModel.savedCount)
        .adminCraftedAria(
            editor: viewModel.ariaEditor, panel: $viewModel.ariaPanel, asksDiscard: $viewModel.showsAriaDiscard,
            choices: viewModel.ariaPanel.showsScope ? viewModel.ariaChoices : [], summary: viewModel.ariaSummary,
            showsResume: viewModel.showsAriaResume, showsButton: viewModel.canEdit, open: { viewModel.openAria() },
            actions: ariaActions, discardAndOpen: { viewModel.discardEditAndOpenAria() }
        )
        .sheet(isPresented: $viewModel.showsHistory) {
            AdminCraftedVersionHistorySheet(entries: viewModel.historyEntries, selected: viewModel.comparedNumber) {
                viewModel.openCompare($0)
            }
        }
        .alert("Discard changes?", isPresented: $viewModel.showsDiscard) {
            Button("Discard", role: .destructive) { viewModel.discard() }
            Button("Keep editing", role: .cancel) {}
        }
        .sheet(item: $viewModel.sharedFile) { file in
            AdminCraftedActivityView(url: file.url)
                .presentationDetents([.medium, .large])
        }
        .quickLookPreview($viewModel.previewURL)
        .alert("Couldn't write the edits into the file", isPresented: $viewModel.showsShareNotice) {
            Button("Share original") { viewModel.shareOriginal() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Some edits could not be written into the file for certain, so this is the original report.")
        }
        .alert("Something went wrong", isPresented: $viewModel.showsActionError) {
            Button("OK") {}
        } message: {
            Text(viewModel.actionError ?? "")
        }
    }

    // MARK: Contenuto

    /// Lingua e zoom: due righe se non stanno insieme (testo grande).
    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                AdminCraftedReportLanguageMenu(viewModel: viewModel)
                Spacer(minLength: 8)
                if viewModel.phase == .loaded { AdminCraftedReportZoomControls(viewModel: viewModel) }
            }
            VStack(alignment: .leading, spacing: 10) {
                AdminCraftedReportLanguageMenu(viewModel: viewModel)
                if viewModel.phase == .loaded { AdminCraftedReportZoomControls(viewModel: viewModel) }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            AdminCraftedReportLoading()
        case .failed(let message):
            AdminCraftedReportFailure(message: message, hasFile: viewModel.file != nil,
                                      retry: { await viewModel.retry() },
                                      shareOriginal: { viewModel.shareOriginal() })
        case .loaded:
            banner
            AdminCraftedPaperPage(viewModel: viewModel)
        }
    }

    /// Sopra la pagina: il suggerimento mentre si modifica, o "Edited" se non è più il rapporto com'era.
    @ViewBuilder
    private var banner: some View {
        if viewModel.isEditing {
            AdminCraftedReportEditHint(nextNumber: viewModel.nextNumber)
        } else if viewModel.comparedNumber == nil, let line = viewModel.editedLine {
            AdminCraftedEditedBanner(line: line) { viewModel.openCompare(viewModel.currentNumber) }
        }
    }

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
    private var toolbar: some ToolbarContent {
        if viewModel.isEditing {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { viewModel.requestCancel() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(viewModel.saveTitle) { viewModel.save() }
                    .disabled(!viewModel.isDirty)
            }
            ToolbarItem(placement: .keyboard) {
                Button("Done") { viewModel.endEditingBlock() }
            }
        } else {
            if viewModel.canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit", systemImage: "pencil") { viewModel.startEditing() }
                        .disabled(viewModel.ariaBusy)
                }
            }
            ToolbarItem(placement: .topBarTrailing) { menu }
        }
    }

    private var menu: some View {
        Menu("More", systemImage: "ellipsis.circle") {
            if viewModel.canEdit {
                Button("Version history", systemImage: "clock.arrow.circlepath") { viewModel.openHistory() }
                    .disabled(viewModel.ariaBusy)
            }
            Button("Share", systemImage: "square.and.arrow.up") { Task { await viewModel.share() } }
                .disabled(viewModel.document == nil || viewModel.isPreparingShare)
            Button("Preview original", systemImage: "doc.viewfinder") { viewModel.previewOriginal() }
                .disabled(viewModel.file == nil)
        }
    }
}
