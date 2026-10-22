//
//  AdminWorkOrderActivityViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Attività di un ordine: messaggi (GET/POST /messages) e storico delle modifiche (GET /v1/audit-log).
//  I messaggi si mostrano come una chat (il più recente in fondo); lo storico come una linea del tempo,
//  dal più recente, a pagine. Chi ha fatto la modifica arriva come id: il nome viene da GET /v1/users.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminWorkOrderActivityViewModel {
    let orderId: String
    let backend: AriaBackend

    var section: AdminWorkOrderActivitySection = .messages

    private(set) var messages: [AdminWorkOrderMessage] = []
    private(set) var history: [AdminWorkOrderAuditEntry] = []
    private(set) var historyTotal: Int?
    /// L'ultima pagina era piena: forse ce ne sono altre (quando il totale manca).
    private var lastPageWasFull = false
    private var userNames: [String: String] = [:]
    private var hasLoadedUsers = false

    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var isLoadingMore = false
    private(set) var isSending = false
    private(set) var errorMessage: String?

    /// Il testo del messaggio in scrittura.
    var draft = ""

    static let pageSize = 30

    init(orderId: String, backend: AriaBackend) {
        self.orderId = orderId
        self.backend = backend
    }

    private var api: AdminWorkOrdersAPI { AdminWorkOrdersAPI(api: backend.api) }

    // MARK: Caricamento

    /// Alla prima apertura della scheda e a ogni aggiornamento del dettaglio.
    /// Messaggi e prima pagina dello storico insieme; le righe già mostrate restano finché arrivano le nuove.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let api = api, id = orderId
        async let messages = Self.result { try await api.messages(id) }
        async let page = Self.result { try await api.auditLog(id, limit: Self.pageSize, offset: 0) }
        await loadUsersIfNeeded()
        var failure: (any Error)?
        switch await messages {
        case .success(let rows): self.messages = Self.chronological(rows)
        case .failure(let error): failure = error
        }
        switch await page {
        case .success(let page):
            history = page.items
            historyTotal = page.total
            lastPageWasFull = page.items.count >= Self.pageSize
        case .failure(let error): failure = failure ?? error
        }
        errorMessage = failure.flatMap { AdminWorkOrderFailure.message(for: $0, backend: backend) }
        hasLoaded = true
    }

    /// Lo storico dopo l'ultima riga mostrata.
    func loadMoreHistory() async {
        guard hasMoreHistory, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await api.auditLog(orderId, limit: Self.pageSize, offset: history.count)
            let known = Set(history.map(\.id))
            history += page.items.filter { !known.contains($0.id) }
            historyTotal = page.total ?? historyTotal
            lastPageWasFull = page.items.count >= Self.pageSize
        } catch {
            if let message = AdminWorkOrderFailure.message(for: error, backend: backend) { errorMessage = message }
        }
    }

    var hasMoreHistory: Bool {
        if let historyTotal { return history.count < historyTotal }
        return lastPageWasFull
    }

    /// I nomi delle persone per lo storico: un di più, se il ruolo non li legge restano gli id.
    private func loadUsersIfNeeded() async {
        guard !hasLoadedUsers else { return }
        hasLoadedUsers = true
        guard let users = try? await api.users() else { return }
        userNames = Dictionary(users.map { ($0.id, $0.displayName) }) { first, _ in first }
    }

    // MARK: Messaggi

    /// Chi scrive: il nome dell'account, o la sua email.
    private var author: String? {
        guard let account = backend.mobileAccount else { return nil }
        let name = account.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? account.email : name
    }

    var canSend: Bool {
        !isSending && author != nil && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func send() async {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend, let author else { return }
        isSending = true
        defer { isSending = false }
        do {
            try await api.postMessage(orderId, author: author, content: content)
            draft = ""
            errorMessage = nil
            if let rows = try? await api.messages(orderId) { messages = Self.chronological(rows) }
        } catch {
            if let message = AdminWorkOrderFailure.message(for: error, backend: backend) { errorMessage = message }
        }
    }

    var messageRows: [AdminWorkOrderMessageRowItem] {
        let me = author
        return messages.map { message in
            AdminWorkOrderMessageRowItem(
                id: message.id,
                author: message.author ?? String(localized: "Anonymous"),
                text: message.content,
                time: message.createdAt.map(Self.relative),
                isMine: me != nil && message.author == me
            )
        }
    }

    // MARK: Storico

    var historyRows: [AdminWorkOrderAuditRowItem] {
        history.map { entry in
            AdminWorkOrderAuditRowItem(
                id: entry.id,
                icon: Self.icon(entry.action),
                title: Self.actionLabel(entry.action),
                who: who(entry.userId),
                time: entry.createdAt.map(Self.relative),
                changes: entry.changes.map { change in
                    AdminWorkOrderAuditChangeItem(
                        id: change.field,
                        field: Self.fieldLabel(change.field),
                        old: change.old.flatMap(Self.valueLabel),
                        new: change.new.flatMap(Self.valueLabel) ?? "—"
                    )
                },
                note: entry.changesText
            )
        }
    }

    private func who(_ userId: String?) -> String {
        guard let userId else { return String(localized: "System") }
        if let account = backend.mobileAccount, account.id == userId { return author ?? userId }
        return userNames[userId] ?? userId
    }

    // MARK: Formati

    /// Il server non garantisce l'ordine: il più vecchio in alto, quelli senza data in fondo.
    private static func chronological(_ rows: [AdminWorkOrderMessage]) -> [AdminWorkOrderMessage] {
        rows.enumerated().sorted { a, b in
            switch (a.element.createdAt, b.element.createdAt) {
            case let (x?, y?) where x != y: x < y
            case (nil, _?): false
            case (_?, nil): true
            default: a.offset < b.offset
            }
        }.map(\.element)
    }

    /// "5 min fa" nell'ultima settimana, poi la data.
    static func relative(_ date: Date) -> String {
        if abs(date.timeIntervalSinceNow) < 7 * 24 * 3600 {
            return date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
        }
        return AdminWorkOrderFormat.shortDate(date)
    }

    private static func actionLabel(_ action: String?) -> String {
        switch action?.lowercased() {
        case "create", "created": String(localized: "Created")
        case "update", "updated": String(localized: "Updated")
        case "delete", "deleted": String(localized: "Deleted")
        case "soft_delete": String(localized: "Archived")
        case "restore", "restored": String(localized: "Restored")
        case let other?: fieldLabel(other)
        case nil: String(localized: "Changed")
        }
    }

    private static func icon(_ action: String?) -> String {
        switch action?.lowercased() {
        case "create", "created": "plus.circle.fill"
        case "delete", "deleted": "trash.circle.fill"
        case "soft_delete": "archivebox.circle.fill"
        case "restore", "restored": "arrow.uturn.backward.circle.fill"
        default: "pencil.circle.fill"
        }
    }

    /// "assigned_to" o "assignedTo" → "Assigned to".
    private static func fieldLabel(_ field: String) -> String {
        var words: [String] = []
        var current = ""
        for character in field {
            if character == "_" || character == "-" || character == " " {
                if !current.isEmpty { words.append(current) }
                current = ""
            } else if character.isUppercase, !current.isEmpty {
                words.append(current)
                current = String(character)
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { words.append(current) }
        let text = words.joined(separator: " ").lowercased()
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// Testo breve di un valore: date leggibili, sì/no, JSON compatto per il resto. `nil` se vuoto.
    private static func valueLabel(_ value: AriaJSON) -> String? {
        switch value {
        case .null: return nil
        case .bool(let flag): return flag ? String(localized: "Yes") : String(localized: "No")
        case .string(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }
            if trimmed.count >= 10, trimmed.contains("-"), trimmed.contains("T"), let date = AriaWireDate.parse(trimmed) {
                return AdminWorkOrderFormat.dateTime(date)
            }
            return trimmed
        case .number: return value.stringValue
        case .array(let items) where items.isEmpty: return nil
        case .object, .array: return value.compactDescription
        }
    }

    // MARK: Errori

    private static func result<T: Sendable>(_ body: @Sendable () async throws -> T) async -> Result<T, any Error> {
        do { return .success(try await body()) } catch { return .failure(error) }
    }
}

/// Un messaggio come lo mostra la chat.
nonisolated struct AdminWorkOrderMessageRowItem: Identifiable, Hashable, Sendable {
    let id: String
    let author: String
    let text: String
    let time: String?
    let isMine: Bool
}

/// Una voce dello storico.
nonisolated struct AdminWorkOrderAuditRowItem: Identifiable, Hashable, Sendable {
    let id: String
    let icon: String
    let title: String
    let who: String
    let time: String?
    let changes: [AdminWorkOrderAuditChangeItem]
    /// `changes` non strutturato, così com'è.
    let note: String?
}

nonisolated struct AdminWorkOrderAuditChangeItem: Identifiable, Hashable, Sendable {
    let id: String
    let field: String
    let old: String?
    let new: String
}
