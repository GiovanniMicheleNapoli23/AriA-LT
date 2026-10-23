//
//  AdminCraftedArtifactReaderViewModel+Versions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Le versioni dell'artifact: quella attuale stesa sopra la risposta di Aria, la cronologia, il confronto
//  con l'originale o con la precedente (parole per il testo, righe per le tabelle) e il ripristino, che è
//  una versione nuova: quella sostituita resta nella cronologia.
//

import Foundation

extension AdminCraftedArtifactReaderViewModel {
    // MARK: Versione attuale

    var versions: [AdminCraftedArtifactVersion] { artifact?.versions ?? [] }
    var currentNumber: Int { AdminCraftedEditing.currentNumber(versions.map(\.number)) }
    var nextNumber: Int { currentNumber + 1 }
    var currentEdits: AdminCraftedArtifactEdits { AdminCraftedEditing.edits(of: versions, number: currentNumber) }

    var currentLabel: String { AdminCraftedVersionMeta.label(currentNumber) }

    /// "versione 3 di Marco, 23 ott": la riga sopra un artifact letto come modificato.
    var editedLine: String? { versions.last.map { AdminCraftedVersionMeta($0).editedLine } }

    // MARK: Cronologia

    /// Si calcola quando si apre, non a ogni disegno: ogni riga è un confronto di parole.
    func openHistory() {
        guard canEdit, let artifact else { return }
        let versions = self.versions
        let parts = self.parts
        historyEntries = AdminCraftedVersionHistoryEntry.entries(
            metas: versions.map { AdminCraftedVersionMeta($0) }, current: currentNumber, createdAt: artifact.createdAt
        ) { index in
            AdminCraftedEditing.countChanges(parts: parts, base: index > 0 ? versions[index - 1].edits : .none,
                                             next: versions[index].edits)
        }
        showsHistory = true
    }

    /// La versione che si sta confrontando, per evidenziarla nella cronologia.
    var comparedNumber: Int? {
        if case .compare(let number, _) = mode { return number }
        return nil
    }

    // MARK: Confronto

    var isComparing: Bool { comparedNumber != nil && canEdit }

    func openCompare(_ number: Int, against: AdminCraftedCompareAgainst = .original) {
        guard canEdit else { return }
        let base: AdminCraftedArtifactEdits = against == .previous && number > 1
            ? AdminCraftedEditing.edits(of: versions, number: number - 1) : .none
        let next = AdminCraftedEditing.edits(of: versions, number: number)
        let parts = self.parts
        let meta = versions.first { $0.number == number }.map { AdminCraftedVersionMeta($0) }
        compareHeader = AdminCraftedCompareHeader(
            number: number, meta: meta, count: AdminCraftedEditing.countChanges(parts: parts, base: base, next: next),
            against: against, current: currentNumber
        )
        compareBlocks = AdminCraftedCompareBlock.blocks(parts: parts, base: base, next: next)
        mode = .compare(number: number, against: against)
        showsHistory = false
    }

    func setAgainst(_ against: AdminCraftedCompareAgainst) {
        if case .compare(let number, _) = mode { openCompare(number, against: against) }
    }

    func closeCompare() {
        mode = .read
        compareHeader = nil
        compareBlocks = []
    }

    // MARK: Ripristino

    /// Rimette una versione com'era, come versione nuova.
    func restore(_ number: Int) {
        guard canEdit else { return }
        let edits = AdminCraftedEditing.edits(of: versions, number: number)
        store.addVersion(artifactId, edits: edits, author: authorName, restoredFrom: number)
        closeCompare()
        savedCount += 1
    }
}
