//
//  AdminMaintenancePlan.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un piano di manutenzione preventiva (MaintenancePlanResponse di /v1/maintenance-plans).
//  Lettura tollerante: solo il nome e la frequenza sono garantiti, il resto può mancare.
//

import Foundation

nonisolated struct AdminMaintenancePlan: Decodable, Sendable, Identifiable, Hashable {
    /// L'id del server: senza, il piano si vede ma non si modifica né si allega nulla.
    let serverId: String?
    var name: String
    /// Valore grezzo (`daily`, `weekly`…), vedi AdminMaintenanceFrequency.
    var frequency: String
    /// Intervallo in ore, quando il piano è a ore invece che a calendario.
    var frequencyHours: Double?
    /// Valore grezzo (`approved`, `draft`…), vedi AdminMaintenanceStatus.
    var status: String?
    var assetTag: String?
    var relatedAssetTags: [String]
    var plantId: String?
    var category: String?
    var zone: String?
    var description: String?
    var tasks: [String]
    var spareParts: [String]
    var estimatedDurationMin: Int?
    var recurrenceType: String?
    var startsOn: Date?
    var endsOn: Date?
    var daysOfWeek: [String]
    var lastDoneAt: Date?
    var nextDueAt: Date?
    var createdAt: Date?
    var updatedAt: Date?
    /// Quanto è sicura l'estrazione automatica (0…1) per i piani proposti dall'AI.
    var confidence: Double?

    var id: String { serverId ?? "\(plantId ?? "")|\(assetTag ?? "")|\(name)" }

    private enum CodingKeys: String, CodingKey {
        case id, name, frequency, frequencyHours, status, assetTag, relatedAssetTags, plantId, category, zone
        case description, tasks, spareParts, estimatedDurationMin, recurrenceType, startsOn, endsOn, daysOfWeek
        case lastDoneAt, nextDueAt, createdAt, updatedAt, confidence
    }

    init(from decoder: any Decoder) throws {
        let f = try AdminWorkOrderFields(decoder, keyedBy: CodingKeys.self)
        serverId = f.id(.id)
        name = f.text(.name) ?? String(localized: "Untitled plan")
        frequency = f.text(.frequency) ?? AdminMaintenanceFrequency.monthly.rawValue
        frequencyHours = f.double(.frequencyHours)
        status = f.text(.status)
        assetTag = f.text(.assetTag)
        relatedAssetTags = f.array(String.self, .relatedAssetTags)
        plantId = f.id(.plantId)
        category = f.text(.category)
        zone = f.text(.zone)
        description = f.text(.description)
        tasks = f.array(String.self, .tasks)
        spareParts = f.array(String.self, .spareParts)
        estimatedDurationMin = f.int(.estimatedDurationMin)
        recurrenceType = f.text(.recurrenceType)
        startsOn = f.date(.startsOn)
        endsOn = f.date(.endsOn)
        daysOfWeek = f.array(String.self, .daysOfWeek)
        lastDoneAt = f.date(.lastDoneAt)
        nextDueAt = f.date(.nextDueAt)
        createdAt = f.date(.createdAt)
        updatedAt = f.date(.updatedAt)
        confidence = f.double(.confidence)
    }

    var dueState: AdminMaintenanceDueState { AdminMaintenanceDueState.state(for: nextDueAt) }

    /// Tutti i testi su cui cerca la barra di ricerca.
    var searchableFields: [String] {
        [name, assetTag, category, zone, description].compactMap { $0 } + relatedAssetTags
    }
}

/// Un ordine di lavoro letto per il piano (GET /v1/work-orders): quanto basta per la riga, più l'id del piano
/// che lo ha generato, con cui si filtra qui perché la rotta non ha quel parametro.
nonisolated struct AdminMaintenanceWorkOrder: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    var title: String
    var status: AdminWorkOrderStatus?
    var priority: AdminWorkOrderPriority?
    var maintenancePlanId: String?
    var dueDate: Date?
    var scheduledDate: Date?
    var completedAt: Date?
    var createdAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id, title, status, priority, maintenancePlanId, dueDate, scheduledDate, completedAt, completedDate, createdAt
    }

    init(from decoder: any Decoder) throws {
        let f = try AdminWorkOrderFields(decoder, keyedBy: CodingKeys.self)
        guard let id = f.id(.id) else {
            throw DecodingError.keyNotFound(CodingKeys.id, .init(codingPath: decoder.codingPath, debugDescription: "id"))
        }
        self.id = id
        title = f.text(.title) ?? String(localized: "Untitled work order")
        status = f.value(AdminWorkOrderStatus.self, .status)
        priority = f.value(AdminWorkOrderPriority.self, .priority)
        maintenancePlanId = f.id(.maintenancePlanId)
        dueDate = f.date(.dueDate)
        scheduledDate = f.date(.scheduledDate)
        completedAt = f.date(.completedAt) ?? f.date(.completedDate)
        createdAt = f.date(.createdAt)
    }

    var isClosed: Bool { status?.isClosed ?? false }

    /// Chiuso: quando; aperto: la scadenza o il giorno previsto; altrimenti la creazione.
    var displayDate: Date? { isClosed ? (completedAt ?? createdAt) : (dueDate ?? scheduledDate ?? createdAt) }
}
