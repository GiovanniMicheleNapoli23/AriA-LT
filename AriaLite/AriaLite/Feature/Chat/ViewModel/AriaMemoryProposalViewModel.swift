//
//  AriaMemoryProposalViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  "Aria dovrebbe ricordarlo?": scartare, mandare agli amministratori così com'è o riscritto.
//  "Invia" non salva niente: il fatto resta in attesa finché un admin non lo approva.
//

import Foundation
import Observation

@MainActor
@Observable
final class AriaMemoryProposalViewModel {
    let proposal: AriaMemoryProposal
    let chat: AriaAgentChat

    // MARK: - State

    private(set) var isEditing = false
    var edited = ""

    init(proposal: AriaMemoryProposal, chat: AriaAgentChat) {
        self.proposal = proposal
        self.chat = chat
    }

    // MARK: - Derived

    /// Un fatto in conflitto con quello che Aria sa si può segnalare ma non riscrivere (422).
    var canReword: Bool { proposal.kind != "conflict" }
    /// Il testo nella lingua dell'operatore, quando la traduzione è arrivata.
    var shown: String { chat.translated(proposal.content, id: proposal.factId) }
    private var trimmedEdit: String { edited.trimmingCharacters(in: .whitespacesAndNewlines) }
    var canSend: Bool { !isEditing || !trimmedEdit.isEmpty }
    /// Il testo riscritto da mandare, o `nil` per mandare il fatto così com'è.
    var sentContent: String? { isEditing ? trimmedEdit : nil }

    // MARK: - Actions

    func startEditing() {
        edited = proposal.content
        isEditing = true
    }

    func cancelEditing() {
        isEditing = false
    }

    func requestTranslation() {
        chat.requestTranslations([(proposal.factId, proposal.content)])
    }
}
