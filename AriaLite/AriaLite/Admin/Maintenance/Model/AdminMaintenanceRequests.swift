//
//  AdminMaintenanceRequests.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Body di creazione di un piano (MaintenancePlanCreate) e della richiesta all'AI (AIImproveRequest).
//  La modifica usa AdminPatchBody: solo i campi cambiati. Le date partono come testo ISO-8601.
//

import Foundation

/// POST /v1/maintenance-plans. I campi `nil` non si scrivono: decide il default del server.
nonisolated struct AdminMaintenancePlanCreate: Encodable, Sendable {
    var name: String
    var frequency: String
    var plantId: String
    var status: String
    var frequencyHours: Double?
    var assetTag: String?
    var relatedAssetTags: [String]
    var category: String?
    var zone: String?
    var description: String?
    var tasks: [String]
    var spareParts: [String]
    var estimatedDurationMin: Int?
    var startsOn: String?
    var endsOn: String?
    var daysOfWeek: [String]
    var lastDoneAt: String?
    var nextDueAt: String?
}

/// POST /v1/maintenance-plans/{plan_id}/ai-improve. L'OpenAPI dice solo `action: string`.
nonisolated struct AdminMaintenanceImproveRequest: Encodable, Sendable {
    var action: String
    var stepIndex: Int?
    var customPrompt: String?
    var language: String?
}
