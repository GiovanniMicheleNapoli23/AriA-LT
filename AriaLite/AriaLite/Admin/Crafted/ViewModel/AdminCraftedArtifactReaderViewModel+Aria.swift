//
//  AdminCraftedArtifactReaderViewModel+Aria.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  "Modifica con Aria" nel lettore di un artifact: le risposte scelte (o tutte) vanno ad Aria come
//  blocchi — un testo per risposta, una tabella per card — com'è la versione attuale, o com'è dopo la
//  proposta già in pagina se è un seguito. Quello che torna si stende sopra e si mostra come confronto con
//  la versione attuale; solo se accettato diventa una versione, firmata Aria per conto di chi l'ha chiesto.
//

import Foundation

/// Una proposta di Aria stesa sul documento: le modifiche complete, e il confronto con la versione attuale già pronto.
nonisolated struct AdminCraftedAriaArtifactProposal: Hashable, Sendable {
    let edits: AdminCraftedArtifactEdits
    let blocks: [AdminCraftedCompareBlock]
    let count: AdminCraftedChangeCount
}

extension AdminCraftedArtifactReaderViewModel {
    // MARK: Stato

    var canAskAria: Bool { canEdit }

    /// Aria sta lavorando, o c'è una proposta da accettare: il resto del lettore sta fermo.
    var ariaBusy: Bool { ariaEditor.isRunning || ariaProposal != nil }

    /// La pillola per riaprire il pannello nascosto.
    var showsAriaResume: Bool { !ariaPanel.isOpen && ariaBusy }

    var ariaSummary: AdminCraftedAriaProposalSummary? {
        ariaProposal.map {
            AdminCraftedAriaProposalSummary(changes: AdminCraftedVersionMeta.summary(of: $0.count),
                                            acceptTitle: String(localized: "Accept as v\(nextNumber)"))
        }
    }

    /// Le risposte fra cui scegliere: il testo, o il titolo della prima tabella.
    var ariaChoices: [AdminCraftedAriaChoice] {
        parts.map { part in
            let title = part.text.map { AdminCraftedAriaText.preview($0) }
                ?? part.tables.first?.title ?? String(localized: "Table")
            return AdminCraftedAriaChoice(id: part.messageId, title: title)
        }
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
        if isComparing { closeCompare() }
        showsHistory = false
        ariaPanel.isOpen = true
    }

    /// "Scarta e chiedi ad Aria": la modifica a mano non salvata si butta.
    func discardEditAndOpenAria() {
        discard()
        openAria()
    }

    func hideAria() { ariaPanel.isOpen = false }

    /// Chiude tutto: ferma Aria, scarta la proposta e dimentica la conversazione.
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
        let base = before?.edits ?? currentEdits
        let blocks = AdminCraftedAriaMapping.artifactBlocks(parts: parts, base: base, only: ariaPanel.scope)
        guard !blocks.isEmpty else { return }
        ariaPanel.instruction = ""
        ariaEditor.ask(
            instruction: instruction, title: title, blocks: blocks,
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

    private func proposal(from changes: [AdminCraftedAriaChange], base: AdminCraftedArtifactEdits) -> AdminCraftedAriaArtifactProposal? {
        let parts = self.parts
        guard let edits = AdminCraftedAriaMapping.artifactEdits(changes, base: base, parts: parts) else { return nil }
        let current = currentEdits
        return AdminCraftedAriaArtifactProposal(
            edits: edits, blocks: AdminCraftedCompareBlock.blocks(parts: parts, base: current, next: edits),
            count: AdminCraftedEditing.countChanges(parts: parts, base: current, next: edits)
        )
    }

    // MARK: Accettare

    /// La proposta diventa una versione, firmata Aria per conto di chi l'ha chiesta.
    func acceptAria() {
        guard let proposal = ariaProposal, let request = ariaEditor.request(requestedBy: authorName) else { return }
        if proposal.edits != AdminCraftedEditing.normalized(currentEdits, parts: parts) {
            store.addVersion(artifactId, edits: proposal.edits, author: authorName, via: request)
            savedCount += 1
        }
        closeAria()
    }

    /// La conversazione in cui Aria ha lavorato, a cui "Apri la conversazione" porta.
    var ariaSessionId: String? { ariaEditor.sessionId }
}
