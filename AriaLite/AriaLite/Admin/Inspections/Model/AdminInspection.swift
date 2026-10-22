//
//  AdminInspection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un'ispezione con la sua checklist (InspectionResponse del backend). Lettura tollerante: serve solo il
//  titolo; l'elenco degli item può mancare. Le derivazioni (avanzamento, scadenza) vivono qui, senza stato.
//

import Foundation

nonisolated struct AdminInspection: Decodable, Sendable, Identifiable, Hashable {
    /// L'id del server: senza, l'ispezione si vede ma non si modifica.
    var serverId: String?
    var title: String
    var assetTag: String?
    var zone: String?
    var plantId: String?
    var assignedTo: String?
    var notes: String?
    var dueDate: Date?
    /// Valore grezzo, vedi AdminInspectionStatus.
    var status: String?
    var completedAt: Date?
    var items: [AdminInspectionItem]
    var createdAt: Date?
    var updatedAt: Date?

    var id: String { serverId ?? title }

    /// Le chiavi arrivano già in camelCase (`.snakeCased()` sull'endpoint).
    private enum CodingKeys: String, CodingKey {
        case id, title, assetTag, zone, plantId, assignedTo, notes, dueDate, status, completedAt, items, createdAt, updatedAt
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func text(_ key: CodingKeys) -> String? {
            guard let value = try? c.decodeIfPresent(AriaFlexibleID.self, forKey: key)?.value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        func date(_ key: CodingKeys) -> Date? { (try? c.decodeIfPresent(AriaWireDate.self, forKey: key))?.value }

        guard let title = text(.title) else {
            throw DecodingError.keyNotFound(CodingKeys.title, .init(codingPath: c.codingPath, debugDescription: "Ispezione senza titolo"))
        }
        self.title = title
        serverId = text(.id)
        assetTag = text(.assetTag)
        zone = text(.zone)
        plantId = text(.plantId)
        assignedTo = text(.assignedTo)
        notes = text(.notes)
        dueDate = date(.dueDate)
        status = text(.status)
        completedAt = date(.completedAt)
        items = ((try? c.decodeIfPresent(AriaLossyArray<AdminInspectionItem>.self, forKey: .items))?.items ?? [])
            .sorted { $0.order < $1.order }
        createdAt = date(.createdAt)
        updatedAt = date(.updatedAt)
    }

    // MARK: Derivazioni

    var knownStatus: AdminInspectionStatus? { AdminInspectionStatus(raw: status) }
    var statusLabel: String? { status.map(AdminInspectionStatus.label(for:)) }
    var isClosed: Bool { knownStatus?.isClosed ?? false }

    var totalCount: Int { items.count }
    var checkedCount: Int { items.filter(\.isChecked).count }
    var uncheckedCount: Int { totalCount - checkedCount }
    /// 0…1; una checklist vuota vale 0.
    var progress: Double { totalCount == 0 ? 0 : Double(checkedCount) / Double(totalCount) }
    var isFullyChecked: Bool { totalCount > 0 && checkedCount == totalCount }

    /// Item non spuntati con una nota: il server non ha un esito negativo, la nota su un controllo aperto
    /// è il segnale che qualcosa non va.
    var flaggedItems: [AdminInspectionItem] { items.filter(\.needsAttention) }

    /// Scaduta: la data è passata e c'è ancora da fare.
    func isOverdue(now: Date = .now) -> Bool {
        guard let dueDate, !isClosed else { return false }
        return dueDate < now
    }

    /// "AST-101 · Zona A": dove si fa.
    var placeLine: String { [assetTag, zone].compactMap { $0 }.joined(separator: " · ") }

    /// Il testo in cui cerca la barra di ricerca: titolo, asset, zona, assegnatario e testo degli item.
    var searchableFields: [String] { [title, assetTag, zone, assignedTo].compactMap { $0 } }
}

/// Un controllo della checklist (InspectionItemResponse): spuntato o no, con una nota libera.
nonisolated struct AdminInspectionItem: Decodable, Sendable, Identifiable, Hashable {
    /// Senza id il server non può aggiornare l'item: resta in sola lettura.
    var serverId: String?
    var order: Int
    var description: String
    var isChecked: Bool
    var notes: String?

    var id: String { serverId ?? "order-\(order)-\(description)" }
    var needsAttention: Bool { !isChecked && notes != nil }

    private enum CodingKeys: String, CodingKey { case id, order, description, isChecked, notes }

    init(serverId: String?, order: Int, description: String, isChecked: Bool = false, notes: String? = nil) {
        self.serverId = serverId
        self.order = order
        self.description = description
        self.isChecked = isChecked
        self.notes = notes
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        serverId = (try? c.decodeIfPresent(AriaFlexibleID.self, forKey: .id))?.value
        order = (try? c.decodeIfPresent(Int.self, forKey: .order)) ?? 0
        description = ((try? c.decodeIfPresent(String.self, forKey: .description)) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        isChecked = (try? c.decodeIfPresent(Bool.self, forKey: .isChecked)) ?? false
        let note = (try? c.decodeIfPresent(String.self, forKey: .notes))?.trimmingCharacters(in: .whitespacesAndNewlines)
        notes = note?.isEmpty == false ? note : nil
    }
}
