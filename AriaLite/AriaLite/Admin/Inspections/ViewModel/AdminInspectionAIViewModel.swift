//
//  AdminInspectionAIViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  "Improve with AI": chiede la proposta a POST /v1/inspections/{id}/ai-improve, la mostra e lascia
//  applicarla (note e controlli scelti, aggiunti in coda alla checklist) o scartarla. Niente si scrive
//  sull'ispezione finché l'utente non preme "Apply".
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminInspectionAIViewModel {
    enum Phase: Equatable {
        case idle
        case running
        case proposal(AdminInspectionAIAnswer)
    }

    let backend: AriaBackend
    let inspection: AdminInspection

    var action: AdminInspectionAIAction = .improve
    var customPrompt = ""
    /// Scrivere il testo proposto nelle note dell'ispezione.
    var appliesNotes = false
    /// Gli indici (in `candidates`) dei controlli da aggiungere.
    var selectedItems: Set<Int> = []

    private(set) var phase: Phase = .idle
    private(set) var candidates: [String] = []
    private(set) var isApplying = false
    private(set) var didFinish = false
    var errorMessage: String?

    /// Scrive sull'ispezione (note, controlli nuovi); torna il motivo dell'errore o `nil`.
    @ObservationIgnored private let apply: (String?, [String]) async -> String?

    init(backend: AriaBackend, inspection: AdminInspection, apply: @escaping (String?, [String]) async -> String?) {
        self.backend = backend
        self.inspection = inspection
        self.apply = apply
    }

    var isRunning: Bool { phase == .running }
    var canRun: Bool {
        guard !isRunning, !isApplying else { return false }
        return action != .custom || !customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var proposal: AdminInspectionAIAnswer? {
        if case .proposal(let answer) = phase { return answer }
        return nil
    }

    /// Il testo proposto, se è diverso dalle note che ci sono già.
    var proposedNotes: String? {
        guard let text = proposal?.text, text != inspection.notes else { return nil }
        return text
    }

    /// C'è qualcosa da scrivere (note scelte o almeno un controllo).
    var canApply: Bool { !isApplying && ((appliesNotes && proposedNotes != nil) || !selectedItems.isEmpty) }

    // MARK: Azioni

    func run() async {
        guard canRun, let id = inspection.serverId else { return }
        phase = .running
        errorMessage = nil
        let prompt = customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = AdminInspectionAIRequest(action: action.rawValue,
                                            language: Locale.current.language.languageCode?.identifier,
                                            customPrompt: action == .custom ? prompt : nil)
        do {
            let json = try await backend.api.call(AdminInspectionsAPI.aiImprove(id: id, body))
            guard !Task.isCancelled else { return }
            let answer = AdminInspectionAIAnswer(json: json)
            candidates = answer.newItems(comparedTo: inspection.items)
            selectedItems = Set(candidates.indices)
            appliesNotes = false
            phase = .proposal(answer)
        } catch {
            phase = .idle
            errorMessage = AdminInspectionsFailure.message(for: error, backend: backend)
        }
    }

    func toggle(_ index: Int) {
        if selectedItems.contains(index) { selectedItems.remove(index) } else { selectedItems.insert(index) }
    }

    func selectAll(_ on: Bool) {
        selectedItems = on ? Set(candidates.indices) : []
    }

    /// Scrive la parte scelta della proposta. In caso di errore il foglio resta aperto con il motivo.
    func applyProposal() async {
        guard canApply else { return }
        isApplying = true
        errorMessage = nil
        defer { isApplying = false }
        let items = selectedItems.sorted().map { candidates[$0] }
        let notes = appliesNotes ? proposedNotes : nil
        if let message = await apply(notes, items) {
            errorMessage = message.isEmpty ? nil : message
        } else {
            didFinish = true
        }
    }

    /// Butta la proposta e torna alla scelta dell'azione.
    func discard() {
        phase = .idle
        candidates = []
        selectedItems = []
        appliesNotes = false
        errorMessage = nil
    }
}

extension AdminInspectionAIViewModel: Identifiable {}
