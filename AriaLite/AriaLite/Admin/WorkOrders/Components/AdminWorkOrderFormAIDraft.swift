//
//  AdminWorkOrderFormAIDraft.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'AI nella creazione: una riga sola con la sfera di Aria, cosa fa e la rotellina mentre lavora ("Draft with Aria" nei
//  dettagli, "Suggest steps with Aria" nei passi). Sotto, la risposta che non è finita nei campi e gli
//  errori; l'avviso "Filled by AI" con Undo.
//

import SwiftUI

struct AdminWorkOrderFormAIButton: View {
    let title: LocalizedStringKey
    let hint: LocalizedStringKey
    let action: AdminWorkOrderAIAction
    let viewModel: AdminWorkOrderFormViewModel
    /// Prima di chiedere all'AI: la vista chiude la tastiera.
    let onDraft: () -> Void

    @ScaledMetric(relativeTo: .body) private var iconSide: CGFloat = 28

    var body: some View {
        Button {
            onDraft()
            Task { await viewModel.draftWithAI(action) }
        } label: {
            HStack(spacing: 12) {
                AriaOrb(mood: viewModel.isDrafting(action) ? .thinking : .idle,
                        isAnimating: viewModel.isDrafting(action), radius: 0.9)
                    .frame(width: iconSide, height: iconSide)
                    // La sfera è uno shader: il pulsante disabilitato non la spegne da solo.
                    .opacity(viewModel.canDraftWithAI ? 1 : 0.4)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.liteText)
                    Group {
                        if viewModel.needsTitleForAI { Text("Write a title first") } else { Text(hint) }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if viewModel.isDrafting(action) { ProgressView() }
            }
            .contentShape(Rectangle())
        }
        .disabled(!viewModel.canDraftWithAI)
    }
}

/// Quello che l'AI ha detto oltre ai campi, gli errori e (se richiesto) "Filled by AI" con Undo.
struct AdminWorkOrderFormAIFeedback: View {
    let viewModel: AdminWorkOrderFormViewModel
    var showsNotice = true

    var body: some View {
        if showsNotice, let notice = viewModel.aiNotice {
            AdminWorkOrderFormAINotice(notice: notice, onUndo: viewModel.undoAIDraft)
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

    @ScaledMetric(relativeTo: .caption) private var orbSide: CGFloat = 14

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Label {
                Text(verbatim: notice)
            } icon: {
                AriaOrb(isAnimating: false).frame(width: orbSide, height: orbSide)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Button("Undo", action: onUndo)
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderless)
        }
    }
}
