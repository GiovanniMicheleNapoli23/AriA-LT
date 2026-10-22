//
//  AdminExtractionDetailViewModel+AI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  "Improve with AI" / "Analyze with AI": chiede all'AI una proposta (azione rapida o richiesta libera),
//  la mostra campo per campo e, se l'utente la applica, la scrive nei campi e la salva con la PATCH.
//

import Foundation

extension AdminExtractionDetailViewModel {
    var aiActions: [AdminExtractionAIAction] { AdminExtractionAIAction.actions(for: item.kind) }

    var isAskingAI: Bool { aiAction != nil }

    var canAskAI: Bool { canEdit && !isAskingAI && !isSaving && !isDeciding }

    var canSendPrompt: Bool { canAskAI && !customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// La lingua dell'app (`it`, `en`): l'AI risponde e traduce in questa.
    private var language: String? { Locale.current.language.languageCode?.identifier }

    func ask(_ action: AdminExtractionAIAction) async {
        guard canAskAI else { return }
        let prompt = customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if action == .custom, prompt.isEmpty { return }
        aiAction = action
        aiError = nil
        proposal = nil
        defer { aiAction = nil }
        let request = AdminExtractionAIRequest(action: action.rawValue,
                                               customPrompt: action == .custom ? prompt : nil,
                                               language: language)
        do {
            let json = try await client.askAI(item, request)
            let answer = AdminExtractionAIProposal(json: json, fields: fields)
            if answer.isEmpty {
                aiError = String(localized: "The AI didn't suggest any change.")
            } else {
                proposal = answer
                if action == .custom { customPrompt = "" }
            }
        } catch {
            aiError = AdminExtractionReviewFailure.message(for: error, backend: backend)
        }
    }

    func sendPrompt() async { await ask(.custom) }

    /// Scrive i valori proposti nei campi e salva.
    func applyProposal() async {
        guard let proposal, !proposal.changes.isEmpty else { return }
        for change in proposal.changes { drafts[change.key] = change.proposed }
        if await save() { self.proposal = nil }
    }

    func discardProposal() {
        proposal = nil
        aiError = nil
    }
}
