//
//  AriaWorkOrderModels.swift
//  AriaLite
//
//  Created by Giovanni Michele on 08/10/26.
//
//  Modelli dei lavori dell'operatore (GET /v1/me → operatorProfile, /v1/work-orders[/{id}]),
//  della procedura a passi e dei loro risultati. Le chiavi sono in camelCase: le risposte sui lavori
//  (snake_case sul filo) ci arrivano già convertite da AriaAPIClient.workOrderData.
//  I valori fissi arrivano come stringhe e si leggono con proprietà tipizzate: un valore
//  nuovo del server non deve far fallire la decodifica dell'intera lista.
//

import Foundation

/// Disponibilità dell'operatore. `available` dura 12 ore e va rinnovato aprendo l'app.
nonisolated enum AriaAvailability: String, Codable, Sendable, CaseIterable {
    case available
    case busy
    case offDuty = "off_duty"

    var localized: String {
        switch self {
        case .available: String(localized: "Available")
        case .busy: String(localized: "Busy")
        case .offDuty: String(localized: "Off duty")
        }
    }

    var systemImage: String {
        switch self {
        case .available: "checkmark.circle.fill"
        case .busy: "minus.circle.fill"
        case .offDuty: "moon.zzz.fill"
        }
    }
}

/// `operatorProfile` di GET /v1/me, e risposta di PUT /v1/me/availability (l'oggetto, senza involucro).
nonisolated struct AriaMobileProfile: Decodable, Sendable, Equatable {
    let id: String
    let name: String
    let email: String
    let specialties: [String]
    /// `nil` se il server manda un valore che l'app non conosce.
    let availability: AriaAvailability?
    let availabilityAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id, name, email, specialties, availability, availabilityAt
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        email = try c.decode(String.self, forKey: .email)
        specialties = try c.decodeIfPresent([String].self, forKey: .specialties) ?? []
        availability = (try c.decodeIfPresent(String.self, forKey: .availability)).flatMap(AriaAvailability.init(rawValue:))
        availabilityAt = try c.decodeIfPresent(AriaWireDate.self, forKey: .availabilityAt)?.value
    }
}

/// Il profilo operatore dentro la risposta di GET /v1/me: `nil` per un utente della piattaforma che non lo è
/// (`operatorProfile` assente o null). Il JSON restituito è quello del solo profilo, com'è nella copia offline.
nonisolated func AriaOperatorProfileJSON(inMe raw: Data) -> Data? {
    guard let profile = (try? JSONDecoder().decode(AriaJSON.self, from: raw))?["operatorProfile"],
          profile.objectValue != nil else { return nil }
    return try? JSONEncoder().encode(profile)
}

/// Body di PUT /v1/me/availability: nessun altro campo (il server risponde 422).
nonisolated struct AriaAvailabilityBody: Encodable, Sendable {
    let availability: AriaAvailability
}

nonisolated enum AriaWorkOrderPriority: Int, Sendable, Comparable {
    case low, medium, high

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    var localized: String {
        switch self {
        case .low: String(localized: "Low")
        case .medium: String(localized: "Medium")
        case .high: String(localized: "High")
        }
    }
}

nonisolated struct AriaWorkOrder: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String?
    /// `reactive` | `preventive`.
    let type: String?
    let category: String?
    /// `high` | `medium` | `low`.
    let priority: String?
    /// `proposed` | `planned` | `assigned` | `in_progress` | `completed` | `verified` | `cancelled`.
    let status: String
    let assetTag: String?
    let plantId: String?
    let zone: String?
    let scheduledDate: Date?
    let dueDate: Date?
    let estimatedDurationMin: Int?
    let assignedAt: Date?
    /// `auto` | `manual`.
    let assignmentSource: String?
    let notes: String?
    let createdAt: Date?
    let updatedAt: Date?
    /// Passi con un risultato finora. Nella lista c'è sempre; il dettaglio ha anche i passi.
    let progress: AriaProgress?
    /// Solo nel dettaglio (GET /v1/work-orders/{id}?include=procedure).
    let procedure: AriaProcedure?

    private enum CodingKeys: String, CodingKey {
        case id, title, description, type, category, priority, status, assetTag, plantId, zone
        case scheduledDate, dueDate, estimatedDurationMin, assignedAt, assignmentSource, notes
        case createdAt, updatedAt, progress, stepProgress, procedure
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func date(_ key: CodingKeys) throws -> Date? { try c.decodeIfPresent(AriaWireDate.self, forKey: key)?.value }
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        type = try c.decodeIfPresent(String.self, forKey: .type)
        category = try c.decodeIfPresent(String.self, forKey: .category)
        priority = try c.decodeIfPresent(String.self, forKey: .priority)
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        assetTag = try c.decodeIfPresent(String.self, forKey: .assetTag)
        plantId = try c.decodeIfPresent(String.self, forKey: .plantId)
        zone = try c.decodeIfPresent(String.self, forKey: .zone)
        scheduledDate = try date(.scheduledDate)
        dueDate = try date(.dueDate)
        estimatedDurationMin = try c.decodeIfPresent(Int.self, forKey: .estimatedDurationMin)
        assignedAt = try date(.assignedAt)
        assignmentSource = try c.decodeIfPresent(String.self, forKey: .assignmentSource)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try date(.createdAt)
        updatedAt = try date(.updatedAt)
        procedure = try c.decodeIfPresent(AriaProcedure.self, forKey: .procedure)
        // La lista lo manda come `step_progress`; il dettaglio ha l'avanzamento anche dentro la procedura.
        progress = try c.decodeIfPresent(AriaProgress.self, forKey: .progress)
            ?? c.decodeIfPresent(AriaProgress.self, forKey: .stepProgress)
            ?? procedure?.progress
    }

    var priorityLevel: AriaWorkOrderPriority? {
        switch priority {
        case "high": .high
        case "medium": .medium
        case "low": .low
        default: nil
        }
    }

    var statusLabel: String {
        switch status {
        case "proposed": String(localized: "Proposed")
        case "planned": String(localized: "Planned")
        case "assigned": String(localized: "Assigned")
        case "in_progress": String(localized: "In progress")
        case "completed": String(localized: "Completed")
        case "verified": String(localized: "Verified")
        case "cancelled": String(localized: "Cancelled")
        default: status.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var typeLabel: String? {
        switch type {
        case "reactive": String(localized: "Reactive")
        case "preventive": String(localized: "Preventive")
        default: type?.capitalized
        }
    }

    var assignmentLabel: String? {
        switch assignmentSource {
        case "auto": String(localized: "Automatic")
        case "manual": String(localized: "Manual")
        default: assignmentSource?.capitalized
        }
    }

    var isClosed: Bool {
        ["completed", "verified", "cancelled"].contains(status)
    }

    /// Scaduto e ancora aperto.
    var isOverdue: Bool {
        guard !isClosed, let dueDate else { return false }
        return dueDate < .now
    }
}

// MARK: - Procedura

/// Passi con un risultato: `done` + `notDone` su `total`.
nonisolated struct AriaProgress: Decodable, Sendable, Hashable {
    let done: Int
    let notDone: Int
    let total: Int

    init(done: Int, notDone: Int, total: Int) {
        self.done = done
        self.notDone = notDone
        self.total = total
    }

    private enum CodingKeys: String, CodingKey { case done, notDone, total }

    /// Un conteggio che manca vale 0: un avanzamento strano non deve far cadere la lista intera.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        done = try c.decodeIfPresent(Int.self, forKey: .done) ?? 0
        notDone = try c.decodeIfPresent(Int.self, forKey: .notDone) ?? 0
        total = try c.decodeIfPresent(Int.self, forKey: .total) ?? 0
    }

    /// Passi con un risultato, fatti o no.
    var reported: Int { done + notDone }

    /// Da 0 a 1; 0 se la procedura non ha passi.
    var fraction: Double { total > 0 ? min(1, Double(reported) / Double(total)) : 0 }
}

/// La procedura di un ordine (campo `procedure` del dettaglio).
nonisolated struct AriaProcedure: Decodable, Sendable, Hashable {
    let steps: [AriaProcedureStep]
    let safetyWarnings: [String]
    let toolsNeeded: [String]
    let partsNeeded: [String]
    let progress: AriaProgress?

    private enum CodingKeys: String, CodingKey {
        case steps, safetyWarnings, toolsNeeded, partsNeeded, progress
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        steps = try c.decodeIfPresent([AriaProcedureStep].self, forKey: .steps) ?? []
        safetyWarnings = try c.decodeIfPresent([AriaJSON].self, forKey: .safetyWarnings)?.compactMap(\.label) ?? []
        toolsNeeded = try c.decodeIfPresent([AriaJSON].self, forKey: .toolsNeeded)?.compactMap(\.label) ?? []
        partsNeeded = try c.decodeIfPresent([AriaJSON].self, forKey: .partsNeeded)?.compactMap(\.label) ?? []
        progress = try c.decodeIfPresent(AriaProgress.self, forKey: .progress)
    }

    /// Tutti i passi hanno un risultato (condizione per completare l'ordine).
    var isFullyReported: Bool { steps.allSatisfy { $0.report != nil } }
}

private extension AriaJSON {
    /// Testo di una voce che il server può mandare come stringa o come oggetto (`name`, `text`, `description`).
    nonisolated var label: String? {
        nonEmptyString ?? ["name", "text", "description", "title"].lazy.compactMap { self[$0]?.nonEmptyString }.first
    }
}

/// Un passo. Si indirizza sempre per `id` (12 esadecimali minuscoli), mai per `number`:
/// un planner può modificare l'elenco.
nonisolated struct AriaProcedureStep: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let number: Int
    let text: String
    /// `nil` finché il passo non ha un risultato.
    let report: AriaStepReport?
}

/// Il risultato di un passo.
nonisolated struct AriaStepReport: Decodable, Sendable, Hashable {
    /// `done` | `not_done`.
    let status: String
    let note: String?
    let photos: [AriaStepPhoto]
    /// `nil` se il passo l'ha spuntato un planner dal desktop.
    let reportedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case status, note, photos, reportedAt
    }

    init(status: String, note: String?, photos: [AriaStepPhoto] = [], reportedAt: Date? = nil) {
        self.status = status
        self.note = note
        self.photos = photos
        self.reportedAt = reportedAt
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = try c.decode(String.self, forKey: .status)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        photos = try c.decodeIfPresent([AriaStepPhoto].self, forKey: .photos) ?? []
        reportedAt = try c.decodeIfPresent(AriaWireDate.self, forKey: .reportedAt)?.value
    }

    var isDone: Bool { status == "done" }
}

/// Foto di un passo. L'`url` scade dopo 10 minuti: non si conserva, si ricarica l'ordine.
nonisolated struct AriaStepPhoto: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let url: URL?
    let mimeType: String

    private enum CodingKeys: String, CodingKey { case id, photoId, url, mimeType }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Il server la chiama `photo_id` nel ticket e nella conferma; `id` in un passo: si accettano entrambe.
        if let id = try c.decodeIfPresent(String.self, forKey: .id) {
            self.id = id
        } else {
            id = try c.decode(String.self, forKey: .photoId)
        }
        url = try? c.decodeIfPresent(URL.self, forKey: .url)
        mimeType = try c.decodeIfPresent(String.self, forKey: .mimeType) ?? "image/jpeg"
    }
}

/// Esito che l'operatore dà a un passo.
nonisolated enum AriaStepResult: Sendable, Equatable {
    case done(note: String?)
    /// La nota è obbligatoria.
    case notDone(note: String)
}

/// Data ISO-8601 in UTC con `Z`: le cifre decimali dei secondi variano e possono mancare,
/// quindi non c'è un pattern fisso. Si toglie la frazione (qui non serve) e si legge il resto.
nonisolated struct AriaWireDate: Decodable, Sendable {
    let value: Date?

    init(from decoder: any Decoder) throws {
        value = Self.parse(try decoder.singleValueContainer().decode(String.self))
    }

    static func parse(_ raw: String) -> Date? {
        var text = raw.trimmingCharacters(in: .whitespaces)
        if let dot = text.firstIndex(of: ".") {
            // Frazione di secondo: dal punto alla prima cifra non numerica (Z, +hh:mm).
            let end = text[text.index(after: dot)...].firstIndex { !$0.isNumber } ?? text.endIndex
            text.removeSubrange(dot..<end)
        }
        if let date = AriaDate.parse(text) { return date }
        // Solo data (`2026-10-07`), per tolleranza.
        return try? Date(text, strategy: Date.ISO8601FormatStyle().year().month().day())
    }
}

/// GET /v1/work-orders: un array di ordini; si accetta anche un oggetto che lo avvolge.
nonisolated struct AriaWorkOrderList: Decodable, Sendable {
    let orders: [AriaWorkOrder]

    private struct Wrapper: Decodable {
        let items: [AriaWorkOrder]?
        let workOrders: [AriaWorkOrder]?
        let data: [AriaWorkOrder]?
    }

    init(from decoder: any Decoder) throws {
        if let array = try? decoder.singleValueContainer().decode([AriaWorkOrder].self) {
            orders = array
        } else {
            let wrapper = try Wrapper(from: decoder)
            orders = wrapper.items ?? wrapper.workOrders ?? wrapper.data ?? []
        }
    }
}
