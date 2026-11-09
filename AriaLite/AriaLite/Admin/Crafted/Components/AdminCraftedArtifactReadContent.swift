//
//  AdminCraftedArtifactReadContent.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Il lettore in lettura: le strisce ("Modificato", "serve la chat"), poi la conversazione con le
//  modifiche dell'ultima versione sopra. Mentre Aria crea mostra quello che ha già scritto, con la
//  rotella. Se il server non si legge, quello che il dispositivo ha tenuto.
//

import SwiftUI

struct AdminCraftedArtifactReadContent: View {
    let viewModel: AdminCraftedArtifactReaderViewModel
    let actions: AriaArtifactActions
    let openChat: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.canEdit, let line = viewModel.editedLine {
                AdminCraftedEditedBanner(line: line) { viewModel.openCompare(viewModel.currentNumber) }
            }
            if viewModel.asksInChat { AdminCraftedNeedsChatBanner(openChat: openChat) }
            ForEach(viewModel.shownMessages) { message in
                AdminCraftedArtifactMessageRow(message: message, actions: actions)
            }
            if viewModel.isGenerating {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Aria is making it").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Il server non si legge (offline…): le card e il testo che il dispositivo ha tenuto, dichiarandolo.
struct AdminCraftedArtifactOfflineContent: View {
    let viewModel: AdminCraftedArtifactReaderViewModel
    let actions: AriaArtifactActions

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AdminSectionNotice(text: String(localized: "The conversation could not be read: this is what this device kept."),
                               isError: true)
            if let detail = viewModel.loadError {
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(viewModel.keptArtifacts) { AriaArtifactView(artifact: $0, actions: actions) }
            if let note = viewModel.keptNote {
                AriaMarkdownView(text: note).textSelection(.enabled)
            }
        }
    }
}
