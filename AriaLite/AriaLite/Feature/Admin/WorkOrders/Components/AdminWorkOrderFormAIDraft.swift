//
//  AdminWorkOrderFormAIDraft.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  "Draft with AI" nella prima pagina della creazione, con la risposta che non è finita nei campi e gli
//  errori; e l'avviso "Filled by AI" con Undo, che resta in cima a ogni pagina finché c'è da rivedere.
//

import SwiftUI

struct AdminWorkOrderFormAIDraftRows: View {
    let viewModel: AdminWorkOrderFormViewModel
    /// Prima di chiedere all'AI: la vista chiude la tastiera.
    let onDraft: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(viewModel.draftActions) { action in
                    Button(action.title, systemImage: action.systemImage) { draft(action) }
                }
            } label: {
                Label("Draft with AI", systemImage: "pencil.and.list.clipboard")
                    .font(.subheadline.weight(.semibold))
            } primaryAction: {
                if let first = viewModel.draftActions.first { draft(first) }
            }
            .disabled(!viewModel.canDraftWithAI)
            .tint(Color.liteAccent)
            Spacer(minLength: 0)
            if viewModel.isDrafting {
                ProgressView().controlSize(.small)
            } else if viewModel.needsTitleForAI {
                Text("Write a title first").font(.caption).foregroundStyle(.tertiary)
            }
        }
        if let note = viewModel.aiNote {
            message(note, systemImage: "text.bubble", tint: .secondary)
        }
        if let failure = viewModel.aiFailure {
            VStack(alignment: .leading, spacing: 4) {
                message(failure.message, systemImage: "exclamationmark.triangle.fill", tint: .orange)
                if !failure.validActions.isEmpty {
                    Text("Actions the server accepts: \(failure.validActions.joined(separator: ", "))")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func draft(_ action: AdminWorkOrderAIAction) {
        onDraft()
        Task { await viewModel.draftWithAI(action) }
    }

    private func message(_ text: String, systemImage: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage).foregroundStyle(tint)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(8)
                .textSelection(.enabled)
            Spacer(minLength: 4)
            Button("Dismiss", systemImage: "xmark") { viewModel.dismissAINote() }
                .labelStyle(.iconOnly)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tertiary)
                .buttonStyle(.borderless)
        }
    }
}

/// "Filled by AI: …" con Undo.
struct AdminWorkOrderFormAINotice: View {
    let notice: String
    let onUndo: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Label(notice, systemImage: "sparkles")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Button("Undo", action: onUndo)
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderless)
        }
    }
}
