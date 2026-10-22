//
//  AdminDowntime.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un fermo macchina di un asset (AssetDowntimeResponse) e i body per registrarlo o modificarlo.
//  Un fermo senza `ended_at` è ancora in corso.
//

import Foundation

nonisolated struct AdminDowntime: Decodable, Sendable, Identifiable, Hashable {
    /// Senza id il fermo si vede ma non si modifica né si elimina.
    let serverId: String?
    let assetTag: String
    /// Il testo del server, per l'id di ripiego quando la data non si legge.
    let startedAtRaw: String
    let startedAt: Date?
    let endedAt: Date?
    /// Il server ha una fine anche se non la sappiamo leggere: il fermo non è "in corso".
    let hasEnd: Bool
    let reason: String?
    let workOrderId: String?
    let plantId: String?
    let createdBy: String?
    let createdAt: Date?

    var id: String { serverId ?? "\(assetTag)|\(startedAtRaw)" }
    var isOpen: Bool { !hasEnd }

    /// Durata: fino ad adesso per un fermo in corso.
    func duration(now: Date = .now) -> TimeInterval? {
        guard let startedAt else { return nil }
        guard let end = endedAt ?? (isOpen ? now : nil) else { return nil }
        return max(0, end.timeIntervalSince(startedAt))
    }

    private enum CodingKeys: String, CodingKey {
        case id, assetTag, startedAt, endedAt, reason, workOrderId, plantId, createdBy, createdAt
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func text(_ key: CodingKeys) -> String? {
            guard let value = try? c.decodeIfPresent(AriaFlexibleID.self, forKey: key)?.value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        assetTag = text(.assetTag) ?? ""
        startedAtRaw = text(.startedAt) ?? ""
        startedAt = AriaWireDate.parse(startedAtRaw)
        let endRaw = text(.endedAt)
        hasEnd = endRaw != nil
        endedAt = endRaw.flatMap(AriaWireDate.parse)
        serverId = text(.id)
        reason = text(.reason)
        workOrderId = text(.workOrderId)
        plantId = text(.plantId)
        createdBy = text(.createdBy)
        createdAt = text(.createdAt).flatMap(AriaWireDate.parse)
    }

    /// "22 ott, 08:30 – 10:15", "22 ott, 08:30 – 23 ott, 09:00" o "Since 22 ott, 08:30".
    var periodText: String {
        guard let startedAt else { return startedAtRaw }
        let start = startedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        guard let endedAt else {
            return isOpen ? String(localized: "Since \(start)") : start
        }
        let sameDay = Calendar.current.isDate(startedAt, inSameDayAs: endedAt)
        let end = sameDay ? endedAt.formatted(date: .omitted, time: .shortened)
                          : endedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        return "\(start) – \(end)"
    }

    /// "2h 15m", "3d 4h".
    func durationText(now: Date = .now) -> String? {
        guard let seconds = duration(now: now) else { return nil }
        return Duration.seconds(seconds.rounded())
            .formatted(.units(allowed: [.days, .hours, .minutes], width: .narrow, maximumUnitCount: 2))
    }

    /// Le date vanno sul filo come ISO-8601 in UTC (`2026-10-22T08:30:00Z`): mai `Date` nei body,
    /// l'encoder di AriaEndpoint non ha una strategia per le date.
    static func wire(_ date: Date) -> String { date.formatted(.iso8601) }
}

/// POST /v1/asset-downtime.
nonisolated struct AdminDowntimeCreate: Encodable, Sendable {
    var assetTag: String
    var startedAt: String
    var endedAt: String?
    var reason: String?
    var workOrderId: String?
    var plantId: String
}
