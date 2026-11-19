//
//  AdminUsersAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Le rotte della sezione Users (contratto del 18/11/2026, §1). Due famiglie:
//  - sotto /v1/companies/{companyId}: l'azienda è nel percorso, body e risposte in camelCase (niente `.snakeCased()`);
//  - le vecchie, con l'azienda nell'header `Company-Id` e in snake_case: POST /v1/users, GET e PATCH
//    /v1/members/{id}, i turni (AdminMembersAPI) e PATCH /v1/work-orders/{id}.
//  L'email d'invito va al sito (AriaAuth.sendMobileInviteLink), con il token di sessione.
//

import Foundation

nonisolated struct AdminUsersAPI: Sendable {
    let api: AriaAPIClient
    let companyId: String

    private var company: String { "v1/companies/\(companyId)" }
    private func member(_ userId: String) -> String { "\(company)/members/\(userId)" }

    // MARK: Letture

    /// GET {c}/users: tutti, i posti e i titolari.
    func list() async throws -> AdminUsersPage {
        try await api.call(AriaEndpoint<AdminUsersPage>.get("\(company)/users"))
    }

    /// GET {c}/seats: il tetto del piano, per il pannello dei titolari.
    func seats() async throws -> AdminUserSeatsInfo {
        try await api.call(AriaEndpoint<AdminUserSeatsInfo>.get("\(company)/seats"))
    }

    /// GET {c}/members/{id}/sessions: le sessioni aperte, web e app.
    func sessions(userId: String) async throws -> [AdminUserSession] {
        try await api.call(AriaEndpoint<AriaLossyArray<AdminUserSession>>.get("\(member(userId))/sessions")).items
    }

    // MARK: Scritture (rispondono la riga della persona, o niente)

    /// PUT {c}/members/{id}/level
    @discardableResult
    func setLevel(userId: String, _ change: AdminUserLevelChange) async throws -> AdminUserRow {
        try await api.call(AriaEndpoint<AdminUserRow>.put("\(member(userId))/level", body: change))
    }

    /// PUT {c}/members/{id}/app-access
    @discardableResult
    func setAppAccess(userId: String, on: Bool) async throws -> AdminUserRow {
        try await api.call(AriaEndpoint<AdminUserRow>.put("\(member(userId))/app-access", body: AdminUserSwitch(on: on)))
    }

    /// PUT {c}/members/{id}/field-worker
    @discardableResult
    func setFieldWorker(userId: String, on: Bool) async throws -> AdminUserRow {
        try await api.call(AriaEndpoint<AdminUserRow>.put("\(member(userId))/field-worker", body: AdminUserSwitch(on: on)))
    }

    /// DELETE {c}/members/{id}/sessions/{sessionId} → 204
    func endSession(userId: String, sessionId: String) async throws {
        let _: AriaNoContent = try await api.call(.delete("\(member(userId))/sessions/\(sessionId)"))
    }

    /// DELETE {c}/members/{id}/sessions → 204
    func endAllSessions(userId: String) async throws {
        let _: AriaNoContent = try await api.call(.delete("\(member(userId))/sessions"))
    }

    /// DELETE {c}/members/{id} → 204: esce dall'azienda.
    func remove(userId: String) async throws {
        let _: AriaNoContent = try await api.call(.delete(member(userId)))
    }

    /// DELETE {c}/invites/{invitationId} → 204: il link smette di funzionare, il posto torna libero.
    func revokeInvite(invitationId: String) async throws {
        let _: AriaNoContent = try await api.call(.delete("\(company)/invites/\(invitationId)"))
    }

    // MARK: Rotte con `Company-Id` (snake_case)

    /// POST /v1/users: aggiunge una persona (201, snake_case). Serve l'`id` per l'email.
    func create(_ body: AdminUserCreate) async throws -> AdminMemberCreated {
        try await api.call(AriaEndpoint<AdminMemberCreated>.post("v1/users", body: body).snakeCased())
    }

    /// PATCH /v1/members/{id} con il solo stato.
    func setStatus(userId: String, suspended: Bool) async throws {
        let body = AdminUserStatusChange(status: suspended ? "suspended" : "active")
        let _: AriaNoContent = try await api.call(AriaEndpoint<AriaNoContent>.patch("v1/members/\(userId)", body: body).snakeCased())
    }

    /// PATCH /v1/members/{id} con le sole specialità (la lista intera).
    func setSpecialties(userId: String, _ specialties: [String]) async throws {
        let body = AdminUserSpecialtiesChange(specialties: specialties)
        let _: AriaNoContent = try await api.call(AriaEndpoint<AriaNoContent>.patch("v1/members/\(userId)", body: body).snakeCased())
    }

    /// PATCH /v1/work-orders/{id}: l'ordine va alla persona.
    func assignWorkOrder(id: String, to userId: String, name: String) async throws {
        let body = AdminUserWorkOrderAssignment(assignedToUserId: userId, assignedTo: name)
        let _: AriaNoContent = try await api.call(AriaEndpoint<AriaNoContent>.patch("v1/work-orders/\(id)", body: body).snakeCased())
    }
}
