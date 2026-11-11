//
//  AdminAlarmEvent.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Un evento di allarme come lo manda il backend (AlarmEventResponse): quello che l'impianto ha alzato, letto
//  o no. Non è il record del catalogo (AdminAlarm). Lettura tollerante: servono solo `id` e `alarm_code`
//  (nell'OpenAPI `id` è facoltativo, ma senza non si può segnare come letto); il resto, se illeggibile,
//  vale come assente. Le chiavi arrivano già in camelCase dalla chiamata `.snakeCased()`.
//

import Foundation

nonisolated struct AdminAlarmEvent: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    var alarmCode: String
    var alarmDescription: String?
    /// Gravità come numero del server (default 2).
    var severity: Int
    /// Da dove arriva (default "opc-ua").
    var source: String
    var isRead: Bool
    var readAt: Date?
    var createdAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id, alarmCode, alarmDescription, severity, source, isRead, readAt, createdAt
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func json(_ key: CodingKeys) -> AriaJSON? { try? c.decodeIfPresent(AriaJSON.self, forKey: key) }
        func text(_ key: CodingKeys) -> String? { json(key)?.nonEmptyString }
        guard let id = text(.id), let code = text(.alarmCode) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Alarm event without id or code"))
        }
        self.id = id
        alarmCode = code
        alarmDescription = text(.alarmDescription)
        severity = json(.severity)?.doubleValue.flatMap { Int(exactly: $0.rounded()) } ?? 2
        source = text(.source) ?? "opc-ua"
        isRead = json(.isRead)?.boolValue ?? false
        readAt = text(.readAt).flatMap(AriaWireDate.parse)
        createdAt = text(.createdAt).flatMap(AriaWireDate.parse)
    }
}

/// La risposta di GET /v1/alarm-events/unread-count.
nonisolated struct AdminAlarmEventCount: Decodable, Sendable {
    let count: Int

    private enum CodingKeys: String, CodingKey { case count }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        count = max(0, try c.decodeIfPresent(Int.self, forKey: .count) ?? 0)
    }
}

/// Il filtro dell'elenco (`status` della rotta).
nonisolated enum AdminAlarmEventFilter: String, CaseIterable, Identifiable, Sendable {
    case all, unread, read

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: String(localized: "All")
        case .unread: String(localized: "Unread")
        case .read: String(localized: "Read")
        }
    }
}
