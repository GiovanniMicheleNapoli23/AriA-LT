//
//  AriaTaskProgressStore.swift
//  AriaLite
//
//  Created by Giovanni Michele on 17/10/26.
//
//  La procedura di una conversazione, salvata sul dispositivo con SwiftData, così riaprendo la chat
//  (o rilanciando l'app) riparte da dove era:
//  - le spunte e le segnalazioni sui task, una riga per conversazione (chiavi di AriaAgentChat,
//    indipendenti dall'id del messaggio);
//  - le checklist degli step: il backend le manda solo in streaming e non le mette nello storico,
//    quindi senza questa copia ricaricando la chat gli step sparirebbero.
//

import Foundation
import SwiftData

/// Stato di avanzamento dei task di una conversazione.
@Model
final class AriaTaskProgress {
    @Attribute(.unique) var sessionId: String
    /// Chiavi dei task spuntati.
    var checked: [String]
    /// Segnalazioni sui task (unclear / modify / failed), per chiave.
    var marks: [String: String]
    var updatedAt: Date

    init(sessionId: String, checked: [String], marks: [String: String], updatedAt: Date = .now) {
        self.sessionId = sessionId
        self.checked = checked
        self.marks = marks
        self.updatedAt = updatedAt
    }
}

/// Una checklist arrivata in streaming, legata alla risposta che la conteneva.
@Model
final class AriaSavedTaskList {
    var sessionId: String
    /// L'id della risposta (`response.created`): lo storico del server lo riporta per ogni riga.
    var responseId: String?
    /// Posizione della risposta tra quelle di Aria nella conversazione: di riserva, se manca `responseId`.
    var assistantIndex: Int
    /// La checklist (`AriaTaskList`) in JSON.
    var payload: Data
    var savedAt: Date

    init(sessionId: String, responseId: String?, assistantIndex: Int, payload: Data, savedAt: Date = .now) {
        self.sessionId = sessionId
        self.responseId = responseId
        self.assistantIndex = assistantIndex
        self.payload = payload
        self.savedAt = savedAt
    }
}

final class AriaTaskProgressStore {
    struct Snapshot: Equatable {
        var checked: Set<String> = []
        var marks: [String: String] = [:]

        var isEmpty: Bool { checked.isEmpty && marks.isEmpty }
    }

    struct SavedList: Equatable {
        let responseId: String?
        let assistantIndex: Int
        let list: AriaTaskList
    }

    static let shared = AriaTaskProgressStore()

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    /// `inMemory`: niente file su disco (test e anteprime).
    init(inMemory: Bool = false) {
        let schema = Schema([AriaTaskProgress.self, AriaSavedTaskList.self])
        let disk = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        if let container = try? ModelContainer(for: schema, configurations: disk) {
            self.container = container
        } else {
            // Archivio illeggibile: le spunte valgono finché l'app resta aperta, ma l'app non si ferma.
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            self.container = try! ModelContainer(for: schema, configurations: memory)
        }
    }

    /// Lo stato salvato di una conversazione, se ce n'è uno.
    func load(sessionId: String) -> Snapshot? {
        guard let record = record(for: sessionId) else { return nil }
        return Snapshot(checked: Set(record.checked), marks: record.marks)
    }

    /// Salva lo stato di una conversazione; uno stato vuoto cancella la riga.
    func save(_ snapshot: Snapshot, sessionId: String) {
        let existing = record(for: sessionId)
        if snapshot.isEmpty {
            if let existing { context.delete(existing) }
        } else if let existing {
            existing.checked = snapshot.checked.sorted()
            existing.marks = snapshot.marks
            existing.updatedAt = .now
        } else {
            context.insert(AriaTaskProgress(sessionId: sessionId, checked: snapshot.checked.sorted(), marks: snapshot.marks))
        }
        commit()
    }

    // MARK: Checklist

    /// Le checklist salvate di una conversazione, nell'ordine delle risposte.
    func taskLists(sessionId: String) -> [SavedList] {
        let descriptor = FetchDescriptor<AriaSavedTaskList>(predicate: #Predicate { $0.sessionId == sessionId },
                                                            sortBy: [SortDescriptor(\.assistantIndex)])
        let records = (try? context.fetch(descriptor)) ?? []
        return records.compactMap { record in
            guard let list = try? JSONDecoder().decode(AriaTaskList.self, from: record.payload) else { return nil }
            return SavedList(responseId: record.responseId, assistantIndex: record.assistantIndex, list: list)
        }
    }

    /// Salva la checklist di una risposta; una nuova revisione della stessa risposta sostituisce la vecchia.
    func saveTaskList(_ list: AriaTaskList, sessionId: String, responseId: String?, assistantIndex: Int) {
        guard let payload = try? JSONEncoder().encode(list) else { return }
        let descriptor = FetchDescriptor<AriaSavedTaskList>(
            predicate: #Predicate { $0.sessionId == sessionId && $0.assistantIndex == assistantIndex })
        if let existing = try? context.fetch(descriptor).first {
            existing.responseId = responseId ?? existing.responseId
            existing.payload = payload
            existing.savedAt = .now
        } else {
            context.insert(AriaSavedTaskList(sessionId: sessionId, responseId: responseId,
                                             assistantIndex: assistantIndex, payload: payload))
        }
        commit()
    }

    // MARK: Pulizia

    /// Una conversazione eliminata non lascia né spunte né checklist.
    func forget(sessionId: String) {
        if let existing = record(for: sessionId) { context.delete(existing) }
        try? context.delete(model: AriaSavedTaskList.self, where: #Predicate { $0.sessionId == sessionId })
        commit()
    }

    /// Fine accesso: un altro operatore sullo stesso dispositivo non eredita nulla.
    func forgetAll() {
        try? context.delete(model: AriaTaskProgress.self)
        try? context.delete(model: AriaSavedTaskList.self)
        commit()
    }

    private func record(for sessionId: String) -> AriaTaskProgress? {
        var descriptor = FetchDescriptor<AriaTaskProgress>(predicate: #Predicate { $0.sessionId == sessionId })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func commit() {
        try? context.save()
    }
}
