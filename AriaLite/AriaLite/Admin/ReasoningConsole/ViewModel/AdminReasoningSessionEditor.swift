//
//  AdminReasoningSessionEditor.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Rinomina ed elimina una sessione (PATCH e DELETE /v1/agent/sessions/{id}, via AriaChatAPI).
//  Lo usano sia la lista sia il dettaglio: chi lo crea decide cosa fare dopo (`onRenamed`, `onDeleted`).
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminReasoningSessionEditor {
    @ObservationIgnored private let backend: AriaBackend
    @ObservationIgnored var onRenamed: (AriaSessionSummary) -> Void = { _ in }
    @ObservationIgnored var onDeleted: (String) -> Void = { _ in }

    private(set) var renameTarget: AriaSessionSummary?
    var renameTitle = ""
    private(set) var deleteTarget: AriaSessionSummary?
    private(set) var isWorking = false
    private(set) var errorMessage: String?

    init(backend: AriaBackend) {
        self.backend = backend
    }

    private var api: AriaChatAPI { AriaChatAPI(api: backend.api) }

    // MARK: Presentazione (alert e dialog della vista)

    var showsRename: Bool {
        get { renameTarget != nil }
        set { if !newValue { renameTarget = nil } }
    }

    var showsDeleteConfirmation: Bool {
        get { deleteTarget != nil }
        set { if !newValue { deleteTarget = nil } }
    }

    var showsError: Bool {
        get { errorMessage != nil }
        set { if !newValue { errorMessage = nil } }
    }

    var canCommitRename: Bool {
        let title = renameTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return !title.isEmpty && title != renameTarget?.title && !isWorking
    }

    // MARK: Azioni

    func beginRename(_ session: AriaSessionSummary) {
        renameTitle = session.title ?? ""
        renameTarget = session
    }

    func commitRename() async {
        guard let session = renameTarget, canCommitRename else { return }
        let title = String(renameTitle.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        renameTarget = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await api.rename(sessionId: session.sessionId, title: title)
            onRenamed(AriaSessionSummary(sessionId: session.sessionId, title: title, status: session.status,
                                         createdAt: session.createdAt, lastActivityAt: session.lastActivityAt))
        } catch {
            errorMessage = AdminReasoningConsoleFailure.message(for: error, backend: backend)
        }
    }

    func beginDelete(_ session: AriaSessionSummary) {
        deleteTarget = session
    }

    func confirmDelete() async {
        guard let session = deleteTarget else { return }
        deleteTarget = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await api.delete(sessionId: session.sessionId)
            onDeleted(session.sessionId)
        } catch {
            errorMessage = AdminReasoningConsoleFailure.message(for: error, backend: backend)
        }
    }

    func reset() {
        renameTarget = nil
        renameTitle = ""
        deleteTarget = nil
        isWorking = false
        errorMessage = nil
    }
}
