//
//  AdminWorkOrdersAPI+AI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le rotte dell'AI sugli ordini (ai-assist, ai-draft), gli operatori sul campo per l'assegnazione e il
//  salvataggio del form coi campi che i body comuni non hanno ancora (requested_by, alarm_code).
//  Le risposte dell'AI non hanno schema nell'OpenAPI: arrivano come JSON libero e le legge
//  AdminWorkOrderAIAnswer.
//

import Foundation

extension AdminWorkOrdersAPI {
    // MARK: AI

    /// POST /v1/work-orders/{id}/ai-assist.
    func aiAssist(_ id: String, _ body: AdminWorkOrderAIAssistRequest) async throws -> AriaJSON {
        try await api.call(.post("\(root)/\(id)/ai-assist", body: body).snakeCased())
    }

    /// POST /v1/work-orders/ai-draft: suggerimenti per un ordine non ancora creato.
    func aiDraft(_ body: AdminWorkOrderAIDraftRequest) async throws -> AriaJSON {
        try await api.call(.post("\(root)/ai-draft", body: body).snakeCased())
    }

    // MARK: Operatori

    /// GET /v1/mobile-operators. Niente `.snakeCased()`: la risposta è già in camelCase.
    func mobileOperators() async throws -> [AdminWorkOrderFormOperator] {
        let rows: AriaLossyArray<AdminWorkOrderFormOperator> = try await api.call(.get("v1/mobile-operators"))
        return rows.items
    }

    // MARK: Salvataggio del form

    func create(_ body: AdminWorkOrderFormCreate) async throws -> AdminWorkOrder {
        try await api.call(.post(root, body: body).snakeCased())
    }

    func update(_ id: String, _ body: AdminWorkOrderFormPatch) async throws -> AdminWorkOrder {
        try await api.call(.patch("\(root)/\(id)", body: body).snakeCased())
    }
}

/// POST /v1/work-orders: il body comune più i campi di WorkOrderCreate che non ha.
/// Le chiavi in più si scrivono nello stesso oggetto JSON del body comune.
nonisolated struct AdminWorkOrderFormCreate: Encodable, Sendable {
    var base: AdminWorkOrderCreate
    var requestedBy: String?
    var alarmCode: String?
    /// Il testo JSON della procedura (AdminWorkOrderChecklist).
    var checklistData: String?

    private enum CodingKeys: String, CodingKey { case requestedBy, alarmCode, checklistData }

    func encode(to encoder: any Encoder) throws {
        try base.encode(to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(requestedBy, forKey: .requestedBy)
        try c.encodeIfPresent(alarmCode, forKey: .alarmCode)
        try c.encodeIfPresent(checklistData, forKey: .checklistData)
    }
}

/// PATCH /v1/work-orders/{id}: il body comune più `requested_by`. `.some(nil)` lo svuota.
nonisolated struct AdminWorkOrderFormPatch: Encodable, Sendable {
    var base: AdminWorkOrderUpdate
    var requestedBy: String??

    private enum CodingKeys: String, CodingKey { case requestedBy }

    var isEmpty: Bool { base.isEmpty && requestedBy == nil }

    func encode(to encoder: any Encoder) throws {
        try base.encode(to: encoder)
        guard case .some(let value) = requestedBy else { return }
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let value { try c.encode(value, forKey: .requestedBy) } else { try c.encodeNil(forKey: .requestedBy) }
    }
}
