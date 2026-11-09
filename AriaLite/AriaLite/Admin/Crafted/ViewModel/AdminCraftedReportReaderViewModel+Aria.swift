//
//  AdminCraftedReportReaderViewModel+Aria.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  "Modifica con Aria" nel lettore di un rapporto: un blocco di testo per ogni paragrafo scelto (o per
//  tutti) con il testo com'è nella versione attuale — o com'è dopo la proposta già in pagina, per un
//  seguito. Quello che torna si stende sulla pagina come confronto con la versione attuale (le parole
//  aggiunte e tolte nei paragrafi), e solo se accettato diventa una versione di questa lingua.
//

import Foundation

/// Una proposta di Aria stesa sul rapporto: il testo di ogni paragrafo, e i cambi rispetto alla versione attuale.
nonisolated struct AdminCraftedAriaReportProposal: Hashable, Sendable {
    let texts: [String]
    let diffs: [Int: [AdminCraftedTextDiff.Segment]]
    let count: AdminCraftedChangeCount
}

extension AdminCraftedReportReaderViewModel {
    // MARK: Stato

    var canAskAria: Bool { canEdit }

    /// Aria sta lavorando, o c'è una proposta da accettare: il resto del lettore sta fermo.
    var ariaBusy: Bool { ariaEditor.isRunning || ariaProposal != nil }

    var showsAriaResume: Bool { !ariaPanel.isOpen && ariaBusy }

    var ariaSummary: AdminCraftedAriaProposalSummary? {
        ariaProposal.map {
            AdminCraftedAriaProposalSummary(changes: AdminCraftedVersionMeta.summary(of: $0.count),
                                            acceptTitle: String(localized: "Accept as v\(nextNumber)"))
        }
    }

    /// I paragrafi con del testo, com'è nella versione attuale.
    var ariaChoices: [AdminCraftedAriaChoice] {
        shown.indices.compactMap { index -> AdminCraftedAriaChoice? in
            guard !shown[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return AdminCraftedAriaChoice(id: String(index), title: AdminCraftedAriaText.preview(shown[index]))
        }
    }

    // MARK: Scelta sulla pagina

    func isAriaPicked(_ index: Int) -> Bool {
        ariaPanel.isOpen && ariaPanel.scope.contains(String(index))
    }

    /// Col pannello aperto, prima della prima richiesta, si tocca un paragrafo per sceglierlo.
    func isPickable(_ index: Int) -> Bool {
        guard ariaPanel.isOpen, mode == .read, ariaProposal == nil, ariaEditor.sessionId == nil, !ariaEditor.isRunning,
              shown.indices.contains(index) else { return false }
        return !shown[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func togglePick(_ index: Int) {
        let id = String(index)
        if ariaPanel.scope.contains(id) { ariaPanel.scope.remove(id) } else { ariaPanel.scope.insert(id) }
    }

    // MARK: Aprire e chiudere

    /// Si apre da lettura; da una modifica a mano si lascia quella (chiedendo, se non è salvata).
    func openAria() {
        guard canAskAria else { return }
        if isEditing {
            if isDirty {
                showsAriaDiscard = true
                return
            }
            discard()
        }
        if comparedNumber != nil { closeCompare() }
        showsHistory = false
        ariaPanel.isOpen = true
    }

    func discardEditAndOpenAria() {
        discard()
        openAria()
    }

    func hideAria() { ariaPanel.isOpen = false }

    func closeAria() {
        ariaEditor.reset()
        ariaProposal = nil
        ariaPanel = AdminCraftedAriaPanelState()
    }

    // MARK: Richiesta

    func sendAria() {
        let instruction = ariaPanel.instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canAskAria, !instruction.isEmpty, !ariaEditor.isRunning else { return }
        // Quello che c'era in pagina prima: se la richiesta non arriva in fondo, torna.
        let before = ariaProposal
        let base = before?.texts ?? shown
        let blocks = AdminCraftedAriaMapping.reportBlocks(texts: base, only: Set(ariaPanel.scope.compactMap { Int($0) }))
        guard !blocks.isEmpty else { return }
        ariaPanel.instruction = ""
        ariaEditor.ask(
            instruction: instruction, title: title, blocks: blocks, locale: locale,
            onChanges: { [weak self] changes in
                guard let self else { return }
                ariaProposal = proposal(from: changes, base: base) ?? before
            },
            completion: { [weak self] outcome in
                guard let self else { return }
                if case .proposal(let result) = outcome {
                    // Un seguito che non cambia niente lascia la proposta che c'era.
                    ariaProposal = proposal(from: result.changes, base: base) ?? before
                } else {
                    ariaProposal = before
                }
            }
        )
    }

    func stopAria() { ariaEditor.cancel() }

    /// La conversazione in cui Aria ha lavorato, a cui "Apri la conversazione" porta.
    var ariaSessionId: String? { ariaEditor.sessionId }

    private func proposal(from changes: [AdminCraftedAriaChange], base: [String]) -> AdminCraftedAriaReportProposal? {
        guard let texts = AdminCraftedAriaMapping.reportTexts(changes, base: base) else { return nil }
        let current = shown
        var diffs: [Int: [AdminCraftedTextDiff.Segment]] = [:]
        var count = AdminCraftedChangeCount()
        for index in texts.indices where index < current.count && texts[index] != current[index] {
            let segments = AdminCraftedTextDiff.diff(before: current[index], after: texts[index])
            diffs[index] = segments
            count.add(segments)
        }
        return AdminCraftedAriaReportProposal(texts: texts, diffs: diffs, count: count)
    }

    // MARK: Accettare

    /// La proposta diventa una versione di questa lingua, firmata Aria per conto di chi l'ha chiesta.
    func acceptAria() {
        guard let proposal = ariaProposal, let request = ariaEditor.request(requestedBy: authorName) else { return }
        let edits = AdminCraftedReportEditing.editsFrom(originals, proposal.texts)
        if !AdminCraftedReportEditing.sameEdits(originals, edits, currentEdits) {
            versions.add(versionKey, edits: edits, author: authorName, via: request)
            savedCount += 1
        }
        closeAria()
        refreshShown()
    }
}
