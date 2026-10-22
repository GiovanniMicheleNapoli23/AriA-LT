//
//  AdminWorkOrder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un ordine di lavoro come lo vede la web (WorkOrderResponse di /v1/work-orders), in camelCase:
//  la chiamata è `.snakeCased()`, quindi `asset_tag` arriva già come `assetTag`.
//  Obbligatori solo id e titolo: ogni altro campo che manca o non si legge vale `nil`.
//

import Foundation

nonisolated struct AdminWorkOrder: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    var title: String
    var type: AdminWorkOrderType?
    var category: String?
    var priority: AdminWorkOrderPriority?
    var status: AdminWorkOrderStatus?
    var assetTag: String?
    var alarmCode: String?
    var maintenancePlanId: String?
    var plantId: String?
    var zone: String?
    var description: String?

    // Assegnazione
    /// Nome libero di chi lo esegue (campo storico, accanto agli id).
    var assignedTo: String?
    var assignedToTeamId: String?
    var assignedToUserId: String?
    var assignmentSource: AdminWorkOrderAssignmentSource?
    var assignedAt: Date?
    var autoAssignNote: String?
    var requestedBy: String?
    var verifiedBy: String?

    // Note e costi
    var notes: String?
    var resolutionNotes: String?
    var feedback: String?
    var estimatedDurationMin: Int?
    var actualDurationMin: Int?
    var laborHours: Double?
    var laborCost: Double?
    var partsCost: Double?

    // Date
    var scheduledDate: Date?
    var dueDate: Date?
    var startedAt: Date?
    var completedAt: Date?
    var completedDate: Date?
    var createdAt: Date?
    var updatedAt: Date?

    /// Passi con un risultato: nella lista come `step_progress`, nel dettaglio anche dentro la procedura.
    var stepProgress: AdminWorkOrderStepProgress?
    /// Solo con `?include=procedure`.
    var procedure: AdminWorkOrderProcedure?

    private enum CodingKeys: String, CodingKey {
        case id, title, type, category, priority, status, assetTag, alarmCode, maintenancePlanId, plantId, zone
        case description, assignedTo, assignedToTeamId, assignedToUserId, assignmentSource, assignedAt
        case autoAssignNote, requestedBy, verifiedBy, notes, resolutionNotes, feedback
        case estimatedDurationMin, actualDurationMin, laborHours, laborCost, partsCost
        case scheduledDate, dueDate, startedAt, completedAt, completedDate, createdAt, updatedAt
        case stepProgress, procedure
    }

    init(from decoder: any Decoder) throws {
        let f = try AdminWorkOrderFields(decoder, keyedBy: CodingKeys.self)
        // Senza id l'ordine non si può aprire né modificare: la riga si scarta (AriaLossyArray).
        guard let id = f.id(.id) else {
            throw DecodingError.keyNotFound(CodingKeys.id, .init(codingPath: decoder.codingPath, debugDescription: "id"))
        }
        self.id = id
        title = try f.container.decode(String.self, forKey: .title)
        type = f.value(AdminWorkOrderType.self, .type)
        category = f.text(.category)
        priority = f.value(AdminWorkOrderPriority.self, .priority)
        status = f.value(AdminWorkOrderStatus.self, .status)
        assetTag = f.text(.assetTag)
        alarmCode = f.text(.alarmCode)
        maintenancePlanId = f.id(.maintenancePlanId)
        plantId = f.id(.plantId)
        zone = f.text(.zone)
        description = f.text(.description)
        assignedTo = f.text(.assignedTo)
        assignedToTeamId = f.id(.assignedToTeamId)
        assignedToUserId = f.id(.assignedToUserId)
        assignmentSource = f.value(AdminWorkOrderAssignmentSource.self, .assignmentSource)
        assignedAt = f.date(.assignedAt)
        autoAssignNote = f.text(.autoAssignNote)
        requestedBy = f.text(.requestedBy)
        verifiedBy = f.text(.verifiedBy)
        notes = f.text(.notes)
        resolutionNotes = f.text(.resolutionNotes)
        feedback = f.text(.feedback)
        estimatedDurationMin = f.int(.estimatedDurationMin)
        actualDurationMin = f.int(.actualDurationMin)
        laborHours = f.double(.laborHours)
        laborCost = f.double(.laborCost)
        partsCost = f.double(.partsCost)
        scheduledDate = f.date(.scheduledDate)
        dueDate = f.date(.dueDate)
        startedAt = f.date(.startedAt)
        completedAt = f.date(.completedAt)
        completedDate = f.date(.completedDate)
        createdAt = f.date(.createdAt)
        updatedAt = f.date(.updatedAt)
        procedure = f.value(AdminWorkOrderProcedure.self, .procedure)
        stepProgress = f.value(AdminWorkOrderStepProgress.self, .stepProgress) ?? procedure?.progress
    }

    var isClosed: Bool { status?.isClosed ?? false }

    /// Aperto e oltre la scadenza.
    func isOverdue(now: Date = .now) -> Bool {
        guard let dueDate, !isClosed else { return false }
        return dueDate < now
    }
}

/// Quanti passi hanno un risultato (fatti o non fatti) su quanti sono.
nonisolated struct AdminWorkOrderStepProgress: Decodable, Sendable, Hashable {
    var done: Int
    var notDone: Int
    var total: Int

    private enum CodingKeys: String, CodingKey { case done, notDone, total }

    init(done: Int, notDone: Int, total: Int) {
        self.done = done
        self.notDone = notDone
        self.total = total
    }

    init(from decoder: any Decoder) throws {
        let f = try AdminWorkOrderFields(decoder, keyedBy: CodingKeys.self)
        done = f.int(.done) ?? 0
        notDone = f.int(.notDone) ?? 0
        total = f.int(.total) ?? 0
    }

    var reported: Int { done + notDone }
    var fraction: Double { total > 0 ? min(1, Double(reported) / Double(total)) : 0 }
}
