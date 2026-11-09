//
//  AdminCraftedReportReaderViewModel+Versions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Modifica a mano, versioni e confronto del rapporto. Il rapporto scritto dal backend è la versione 1 e
//  non cambia mai: ogni salvataggio, anche un ripristino, è una versione nuova nella lingua che si legge.
//

import Foundation

extension AdminCraftedReportReaderViewModel {
    // MARK: Versione attuale

    var versionKey: String {
        AdminCraftedReportEditing.key(sessionId: review.sessionId, episode: review.episode ?? 1, locale: locale)
    }

    var storedVersions: [AdminCraftedReportVersion] { versions.versions(versionKey) }
    var currentNumber: Int { storedVersions.last?.number ?? 1 }
    var nextNumber: Int { currentNumber + 1 }

    var currentEdits: AdminCraftedReportEdits {
        AdminCraftedReportEditing.edits(of: storedVersions, number: currentNumber)
    }

    /// La riga sopra un rapporto letto come modificato; `nil` se è quello scritto dal backend.
    var editedLine: String? {
        storedVersions.last.map { AdminCraftedVersionMeta($0).editedLine }
    }

    /// Chi salva: chi ha fatto l'accesso (nome, altrimenti email).
    var authorName: String? {
        let name = backend.mobileAccount?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !name.isEmpty { return name }
        let email = backend.mobileAccount?.email.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return email.isEmpty ? nil : email
    }

    var comparedNumber: Int? {
        if case .compare(let number, _) = mode { return number }
        return nil
    }

    /// Il testo della versione da leggere (o da confrontare) e, nel confronto, i suoi cambi.
    func refreshShown() {
        guard case .compare(let number, let against) = mode else {
            shown = AdminCraftedReportEditing.textsFor(originals, currentEdits)
            diffs = [:]
            compareHeader = nil
            return
        }
        let list = storedVersions
        let edits = AdminCraftedReportEditing.edits(of: list, number: number)
        let baseEdits: AdminCraftedReportEdits = against == .previous && number > 1
            ? AdminCraftedReportEditing.edits(of: list, number: number - 1) : .none
        shown = AdminCraftedReportEditing.textsFor(originals, edits)
        let base = AdminCraftedReportEditing.textsFor(originals, baseEdits)
        var changes: [Int: [AdminCraftedTextDiff.Segment]] = [:]
        var count = AdminCraftedChangeCount()
        for index in shown.indices where shown[index] != base[index] {
            let segments = AdminCraftedTextDiff.diff(before: base[index], after: shown[index])
            changes[index] = segments
            count.add(segments)
        }
        diffs = changes
        let meta = list.first { $0.number == number }.map(AdminCraftedVersionMeta.init)
        compareHeader = AdminCraftedCompareHeader(number: number, meta: meta, count: count, against: against,
                                                  current: currentNumber)
    }

    // MARK: Modifica a mano

    func startEditing() {
        guard canEdit else { return }
        drafts = AdminCraftedReportEditing.textsFor(originals, currentEdits)
        editingIndex = nil
        mode = .edit
        refreshShown()
    }

    /// Annulla: se qualcosa è cambiato prima si chiede.
    func requestCancel() {
        if isDirty { showsDiscard = true } else { discard() }
    }

    func discard() {
        showsDiscard = false
        mode = .read
        drafts = []
        editingIndex = nil
        refreshShown()
    }

    func beginEditing(block index: Int) {
        guard isEditable(index) else { return }
        editingIndex = index
    }

    func endEditingBlock() { editingIndex = nil }

    /// Un paragrafo resta un paragrafo: il file non ha modo di riprendersi un a capo. Un invio in fondo
    /// vale "fatto".
    func setDraft(_ value: String, at index: Int) {
        guard drafts.indices.contains(index) else { return }
        var text = value.replacingOccurrences(of: "\r\n", with: "\n")
        if text.contains("\n") {
            let endedWithReturn = text.last == "\n"
            text = text.split(separator: "\n", omittingEmptySubsequences: true)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if endedWithReturn { editingIndex = nil }
        }
        drafts[index] = text
    }

    /// Salva è acceso solo se qualcosa è davvero cambiato rispetto alla versione attuale.
    var isDirty: Bool {
        isEditing && !AdminCraftedReportEditing.sameEdits(
            originals, AdminCraftedReportEditing.editsFrom(originals, drafts), currentEdits)
    }

    var saveTitle: String { String(localized: "Save as v\(nextNumber)") }

    func save() {
        guard isDirty else { return }
        versions.add(versionKey, edits: AdminCraftedReportEditing.editsFrom(originals, drafts), author: authorName)
        finishWriting()
    }

    /// Rimettere una versione com'era è una versione nuova: la cronologia cresce soltanto.
    func restore(_ number: Int) {
        guard canEdit else { return }
        versions.add(versionKey, edits: AdminCraftedReportEditing.edits(of: storedVersions, number: number),
                     author: authorName, restoredFrom: number)
        finishWriting()
    }

    private func finishWriting() {
        mode = .read
        drafts = []
        editingIndex = nil
        showsHistory = false
        refreshShown()
        savedCount += 1
    }

    // MARK: Confronto e cronologia

    func openCompare(_ number: Int, against: AdminCraftedCompareAgainst = .original) {
        guard canEdit else { return }
        editingIndex = nil
        drafts = []
        mode = .compare(number: number, against: against)
        showsHistory = false
        refreshShown()
    }

    func setAgainst(_ against: AdminCraftedCompareAgainst) {
        guard let number = comparedNumber else { return }
        openCompare(number, against: against)
    }

    func closeCompare() {
        mode = .read
        refreshShown()
    }

    /// Ogni versione dice chi, quando e quanto ha cambiato rispetto a quella prima. Si calcola all'apertura,
    /// non a ogni disegno: ogni riga è un confronto di parole.
    func openHistory() {
        guard canEdit else { return }
        let list = storedVersions
        let originals = originals
        historyEntries = AdminCraftedVersionHistoryEntry.entries(
            metas: list.map(AdminCraftedVersionMeta.init), current: currentNumber,
            createdAt: review.date ?? Date()
        ) { index in
            AdminCraftedReportEditing.countChanges(originals, base: index > 0 ? list[index - 1].edits : .none,
                                                   next: list[index].edits)
        }
        showsHistory = true
    }
}
