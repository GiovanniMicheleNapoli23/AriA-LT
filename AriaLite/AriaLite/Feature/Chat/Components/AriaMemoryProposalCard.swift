//
//  AriaMemoryProposalCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  "Aria dovrebbe ricordarlo?": l'operatore lo scarta, oppure lo manda (anche riscritto) agli amministratori.
//  "Invia" non salva niente: il fatto resta in attesa finché un admin non lo approva. Il testo si mostra
//  nella lingua dell'operatore quando la traduzione è arrivata. La logica sta in AriaMemoryProposalViewModel.
//

import SwiftUI

struct AriaMemoryProposalCard: View {
    let decide: (_ accept: Bool, _ content: String?) -> Void

    @State private var model: AriaMemoryProposalViewModel
    @FocusState private var editorFocused: Bool

    /// Una card per proposta (`ForEach` per id): il view model nasce con la proposta.
    init(proposal: AriaMemoryProposal, chat: AriaAgentChat, decide: @escaping (_ accept: Bool, _ content: String?) -> Void) {
        _model = State(initialValue: AriaMemoryProposalViewModel(proposal: proposal, chat: chat))
        self.decide = decide
    }

    var body: some View {
        AriaCard(tint: .purple) {
            Label("Should Aria remember this?", systemImage: "brain")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.purple)
            if model.isEditing {
                TextField("What Aria should remember", text: $model.edited, axis: .vertical)
                    .font(.system(size: 13))
                    .lineLimit(2...6)
                    .focused($editorFocused)
                    .padding(8)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityIdentifier("memory.editor")
            } else {
                Text(model.shown).font(.system(size: 13))
                    .accessibilityIdentifier("memory.text")
            }
            if let reason = model.proposal.reason, !reason.isEmpty {
                Text(reason).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Text("An admin reviews it before Aria uses it.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            HStack {
                if model.isEditing {
                    Button("Cancel") { model.cancelEditing() }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("memory.cancelEdit")
                } else {
                    Button("Discard") { decide(false, nil) }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("memory.discard")
                    if model.canReword {
                        Button("Edit", systemImage: "pencil") {
                            model.startEditing()
                            editorFocused = true
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Edit before sending")
                        .accessibilityIdentifier("memory.edit")
                    }
                }
                Spacer()
                Button("Send for review") { decide(true, model.sentContent) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.canSend)
                    .accessibilityIdentifier("memory.send")
            }
            .controlSize(.small)
        }
        .preference(key: AriaInlineEditorFocusKey.self, value: editorFocused)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("memory.card")
        .task(id: model.proposal.factId) { model.requestTranslation() }
    }
}
