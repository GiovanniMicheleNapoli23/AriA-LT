//
//  AdminMaintenanceHistoryViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo storico delle modifiche di un piano (GET /v1/audit-log), dal più recente, a pagine.
//  Chi ha fatto la modifica arriva come id: il nome viene da GET /v1/users (se il ruolo lo può leggere).
//  Le voci sono quelle degli ordini di lavoro (AdminWorkOrderAuditEntry) e si mostrano con la stessa linea del tempo.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminMaintenanceHistoryViewModel {
    let planId: String
    let backend: AriaBackend

    private(set) var entries: [AdminWorkOrderAuditEntry] = []
    private(set) var total: Int?
    /// L'ultima pagina era piena: forse ce ne sono altre (quando il totale manca).
    private var lastPageWasFull = false
    private var userNames: [String: String] = [:]
    private var hasLoadedUsers = false

    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?

    static let pageSize = 30

    init(planId: String, backend: AriaBackend) {
        self.planId = planId
        self.backend = backend
    }

    /// Alla prima apertura della scheda e a ogni aggiornamento del dettaglio.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        await loadUsersIfNeeded()
        do {
            let page = try await backend.api.call(AdminMaintenanceAPI.auditLog(planId: planId, limit: Self.pageSize, offset: 0))
            entries = page.items
            total = page.total
            lastPageWasFull = page.items.count >= Self.pageSize
            errorMessage = nil
        } catch {
            if let message = AdminMaintenanceFailure.message(for: error, backend: backend) { errorMessage = message }
        }
        hasLoaded = true
    }

    /// Lo storico dopo l'ultima riga mostrata.
    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await backend.api.call(
                AdminMaintenanceAPI.auditLog(planId: planId, limit: Self.pageSize, offset: entries.count))
            let known = Set(entries.map(\.id))
            entries += page.items.filter { !known.contains($0.id) }
            total = page.total ?? total
            lastPageWasFull = page.items.count >= Self.pageSize
        } catch {
            if let message = AdminMaintenanceFailure.message(for: error, backend: backend) { errorMessage = message }
        }
    }

    var hasMore: Bool {
        if let total { return entries.count < total }
        return lastPageWasFull
    }

    private func loadUsersIfNeeded() async {
        guard !hasLoadedUsers else { return }
        hasLoadedUsers = true
        guard let users = try? await backend.api.call(AdminMaintenanceAPI.users()) else { return }
        userNames = Dictionary(users.items.map { ($0.id, $0.displayName) }) { first, _ in first }
    }

    // MARK: Righe

    var rows: [AdminWorkOrderAuditRowItem] {
        entries.map { entry in
            AdminWorkOrderAuditRowItem(
                id: entry.id,
                icon: AdminMaintenanceAuditFormat.icon(entry.action),
                title: AdminMaintenanceAuditFormat.actionLabel(entry.action),
                who: who(entry),
                time: entry.createdAt.map(Self.relative),
                changes: entry.changes.map { change in
                    AdminWorkOrderAuditChangeItem(
                        id: change.field,
                        field: AdminMaintenanceAuditFormat.fieldLabel(change.field),
                        old: change.old.flatMap(AdminMaintenanceAuditFormat.valueLabel),
                        new: change.new.flatMap(AdminMaintenanceAuditFormat.valueLabel) ?? "—"
                    )
                },
                note: entry.changesText
            )
        }
    }

    /// Il nome della persona: quello dell'account, poi l'elenco utenti, poi il nome che manda il server.
    private func who(_ entry: AdminWorkOrderAuditEntry) -> String {
        guard let userId = entry.userId else { return entry.displayName ?? String(localized: "System") }
        if let account = backend.mobileAccount, account.id == userId {
            let name = account.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? account.email : name
        }
        return userNames[userId] ?? entry.displayName ?? userId
    }

    /// "5 min fa" nell'ultima settimana, poi la data.
    static func relative(_ date: Date) -> String {
        if abs(date.timeIntervalSinceNow) < 7 * 24 * 3600 {
            return date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
        }
        return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }
}
