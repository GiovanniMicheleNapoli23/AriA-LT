//
//  AdminCraftedArtifactReaderViewModel+Editing.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  La modifica a mano: il testo di ogni risposta di Aria e le celle delle tabelle (righe aggiunte e tolte,
//  le colonne restano). La bozza sta in due dizionari semplici (per id di messaggio e per id di tabella):
//  si salva una versione nuova solo se qualcosa è davvero cambiato, Annulla la scarta.
//

import Foundation

extension AdminCraftedArtifactReaderViewModel {
    // MARK: Cosa si può modificare

    /// Solo con la conversazione come l'ha tenuta il server: gli id dei suoi messaggi sono la chiave delle modifiche.
    var settled: Bool { !isGenerating && loadState == .loaded }

    /// Si ricalcolano quando la conversazione si rilegge (`cachedParts`), non a ogni lettura: ogni tabella è JSON da scorrere.
    var parts: [AdminCraftedEditablePart] { settled ? cachedParts : [] }
    var canEdit: Bool { settled && !parts.isEmpty }

    var isEditing: Bool { mode == .edit && canEdit }

    // MARK: Bozza

    func beginEdit() {
        guard canEdit else { return }
        draftTexts = currentEdits.texts
        draftTables = currentEdits.tables
        showsHistory = false
        mode = .edit
    }

    /// La bozza com'è, ridotta a quello che cambia davvero rispetto all'originale di Aria.
    var draftEdits: AdminCraftedArtifactEdits {
        AdminCraftedEditing.normalized(AdminCraftedArtifactEdits(texts: draftTexts, tables: draftTables), parts: parts)
    }

    /// C'è qualcosa da salvare: la bozza differisce dalla versione attuale.
    var isDirty: Bool {
        guard isEditing else { return false }
        return draftEdits != AdminCraftedEditing.normalized(currentEdits, parts: parts)
    }

    var saveTitle: String { String(localized: "Save as v\(nextNumber)") }

    func draftText(_ part: AdminCraftedEditablePart) -> String { draftTexts[part.messageId] ?? part.text ?? "" }

    func setDraftText(_ text: String, messageId: String) { draftTexts[messageId] = text }

    func draftRows(_ table: AdminCraftedEditableTable) -> [AdminCraftedEditedRow] {
        draftTables[table.artifactId] ?? table.originalRows
    }

    func cellText(_ table: AdminCraftedEditableTable, rowId: String, column: AdminCraftedColumn) -> String {
        draftRows(table).first { $0.id == rowId }?.cells[column.key]?.displayText ?? ""
    }

    /// Un numero resta numero finché si legge come tale (setCell della web); vuoto è vuoto.
    func setCell(_ value: String, table: AdminCraftedEditableTable, rowId: String, column: AdminCraftedColumn) {
        var rows = draftRows(table)
        guard let index = rows.firstIndex(where: { $0.id == rowId }) else { return }
        let cell: AdminCraftedCell
        if value.isEmpty {
            cell = .empty
        } else if case .number? = rows[index].cells[column.key], let number = Double(value.trimmingCharacters(in: .whitespaces)) {
            cell = .number(number)
        } else {
            cell = .text(value)
        }
        rows[index].cells[column.key] = cell
        draftTables[table.artifactId] = rows
    }

    func addRow(to table: AdminCraftedEditableTable) {
        let cells = Dictionary(table.columns.map { ($0.key, AdminCraftedCell.empty) }) { first, _ in first }
        draftTables[table.artifactId] = draftRows(table) + [AdminCraftedEditedRow(id: AdminCraftedEditedRow.newID(), cells: cells)]
    }

    func removeRow(_ rowId: String, from table: AdminCraftedEditableTable) {
        draftTables[table.artifactId] = draftRows(table).filter { $0.id != rowId }
    }

    // MARK: Salva e annulla

    func save() {
        guard isDirty else { return }
        store.addVersion(artifactId, edits: draftEdits, author: authorName)
        finishEditing()
        savedCount += 1
    }

    /// Annulla: con modifiche non salvate prima chiede.
    func requestCancel() {
        if isDirty { showsDiscard = true } else { finishEditing() }
    }

    func discard() { finishEditing() }

    private func finishEditing() {
        mode = .read
        draftTexts = [:]
        draftTables = [:]
        showsDiscard = false
    }
}
