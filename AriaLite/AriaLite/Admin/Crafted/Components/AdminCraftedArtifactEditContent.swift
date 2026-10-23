//
//  AdminCraftedArtifactEditContent.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  La modifica a mano di un artifact: per ogni risposta di Aria il testo e le tabelle aperti ai campi.
//  Grafici e altre card non si toccano qui: si cambiano chiedendolo ad Aria in chat.
//

import SwiftUI

struct AdminCraftedArtifactEditContent: View {
    let viewModel: AdminCraftedArtifactReaderViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("You are editing the text, as the Markdown Aria wrote it, and the tables. Charts and other cards change by asking Aria in the chat. Saving makes a new version: Aria's original always stays.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            ForEach(viewModel.parts) { part in
                VStack(alignment: .leading, spacing: 16) {
                    if part.text != nil {
                        AdminCraftedEditableTextBlock(text: Binding(
                            get: { viewModel.draftText(part) },
                            set: { viewModel.setDraftText($0, messageId: part.messageId) }
                        ))
                    }
                    ForEach(part.tables) { table in
                        AdminCraftedEditableTableGrid(viewModel: viewModel, table: table)
                    }
                }
            }
        }
    }
}
