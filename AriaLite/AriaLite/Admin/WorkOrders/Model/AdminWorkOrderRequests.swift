//
//  AdminWorkOrderRequests.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I body di POST e PATCH /v1/work-orders (WorkOrderCreate, WorkOrderUpdate), del completamento e dei passi.
//  Si codificano in snake_case dalla chiamata (tranne CompleteBody); le date sono già stringhe ISO-8601
//  perché l'encoder comune scriverebbe un numero.
//

import Foundation

/// Data per il backend: ISO-8601 in UTC, senza frazioni di secondo.
nonisolated enum AdminWorkOrderWireDate {
    static func string(_ date: Date) -> String {
        date.formatted(.iso8601)
    }
}

/// POST /v1/work-orders. I campi `nil` non si mandano: valgono i default del server.
nonisolated struct AdminWorkOrderCreate: Encodable, Sendable {
    var title: String
    var plantId: String
    var type: String?
    var category: String?
    var priority: String?
    var status: String?
    var assetTag: String?
    var zone: String?
    var description: String?
    var assignedTo: String?
    var assignedToTeamId: String?
    var assignedToUserId: String?
    var estimatedDurationMin: Int?
    var notes: String?
    var scheduledDate: String?
    var dueDate: String?
}

/// PATCH /v1/work-orders/{id}: solo i campi cambiati. Un campo esterno `nil` non si manda;
/// `.some(nil)` si manda come `null` e svuota il campo sul server.
nonisolated struct AdminWorkOrderUpdate: Encodable, Sendable {
    var title: String??
    var type: String??
    var category: String??
    var priority: String??
    var status: String??
    var assetTag: String??
    var plantId: String??
    var description: String??
    var assignedTo: String??
    var assignedToTeamId: String??
    var assignedToUserId: String??
    var estimatedDurationMin: Int??
    var actualDurationMin: Int??
    var notes: String??
    var resolutionNotes: String??
    var scheduledDate: String??
    var dueDate: String??

    private enum CodingKeys: String, CodingKey {
        case title, type, category, priority, status, assetTag, plantId, description, assignedTo
        case assignedToTeamId, assignedToUserId, estimatedDurationMin, actualDurationMin, notes, resolutionNotes
        case scheduledDate, dueDate
    }

    /// Niente da mandare.
    var isEmpty: Bool {
        let fields: [Bool] = [
            title == nil, type == nil, category == nil, priority == nil, status == nil, assetTag == nil,
            plantId == nil, description == nil, assignedTo == nil, assignedToTeamId == nil,
            assignedToUserId == nil, estimatedDurationMin == nil, actualDurationMin == nil, notes == nil,
            resolutionNotes == nil, scheduledDate == nil, dueDate == nil,
        ]
        return !fields.contains(false)
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeChange(title, .title)
        try c.encodeChange(type, .type)
        try c.encodeChange(category, .category)
        try c.encodeChange(priority, .priority)
        try c.encodeChange(status, .status)
        try c.encodeChange(assetTag, .assetTag)
        try c.encodeChange(plantId, .plantId)
        try c.encodeChange(description, .description)
        try c.encodeChange(assignedTo, .assignedTo)
        try c.encodeChange(assignedToTeamId, .assignedToTeamId)
        try c.encodeChange(assignedToUserId, .assignedToUserId)
        try c.encodeChange(estimatedDurationMin, .estimatedDurationMin)
        try c.encodeChange(actualDurationMin, .actualDurationMin)
        try c.encodeChange(notes, .notes)
        try c.encodeChange(resolutionNotes, .resolutionNotes)
        try c.encodeChange(scheduledDate, .scheduledDate)
        try c.encodeChange(dueDate, .dueDate)
    }
}

/// POST /v1/work-orders/{id}/complete. La chiamata non è `.snakeCased()`: la chiave si scrive qui.
/// L'OpenAPI dice `resolutionNotes`, ma la stessa rotta dall'app dell'operatore (provata dal vivo) vuole
/// `resolution_notes`, come AriaCompleteBody.
nonisolated struct AdminWorkOrderCompleteBody: Encodable, Sendable {
    var resolutionNotes: String

    private enum CodingKeys: String, CodingKey { case resolutionNotes = "resolution_notes" }
}

/// PUT /v1/work-orders/{id}/steps/{step_id}: il risultato di un passo (`StepReportBody`).
nonisolated struct AdminWorkOrderStepReportBody: Encodable, Sendable {
    var status: String
    /// `nil` si manda come `null`: il server lo vuole per "fatto" senza nota.
    var note: String?

    private enum CodingKeys: String, CodingKey { case status, note }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(status, forKey: .status)
        try c.encode(note, forKey: .note)
    }
}

/// PUT .../steps/{step_id} e PUT .../steps: la spunta del planner (`StepCheckBody`).
nonisolated struct AdminWorkOrderStepCheckBody: Encodable, Sendable {
    var checked: Bool
}

private nonisolated extension KeyedEncodingContainer {
    /// Un cambiamento: assente non si scrive, `nil` si scrive come `null`.
    mutating func encodeChange<T: Encodable>(_ change: T??, _ key: Key) throws {
        guard case .some(let value) = change else { return }
        if let value { try encode(value, forKey: key) } else { try encodeNil(forKey: key) }
    }
}
