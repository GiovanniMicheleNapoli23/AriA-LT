//
//  AdminMemberShift.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un turno assegnato a un membro (ShiftAssignmentResponse): giorno, tipo di turno, team e note.
//

import Foundation

nonisolated struct AdminMemberShift: Decodable, Sendable, Identifiable, Hashable {
    /// L'id dell'assegnazione: serve a rimuoverla (nell'OpenAPI è facoltativo, ma una riga senza non si può gestire).
    let id: String
    let userId: String
    let teamId: String
    var teamName: String?
    var teamIsAdHoc: Bool
    /// `YYYY-MM-DD`.
    let shiftDate: String
    var shiftType: String
    var notes: String?

    private enum CodingKeys: String, CodingKey {
        case id, userId, teamId, teamName, teamIsAdHoc, shiftDate, shiftType, notes
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func json(_ key: CodingKeys) -> AriaJSON? { try? c.decodeIfPresent(AriaJSON.self, forKey: key) }
        func text(_ key: CodingKeys) -> String? { json(key)?.nonEmptyString }
        guard let id = text(.id), let date = text(.shiftDate) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Shift without id or date"))
        }
        self.id = id
        userId = text(.userId) ?? ""
        teamId = text(.teamId) ?? ""
        teamName = text(.teamName)
        teamIsAdHoc = json(.teamIsAdHoc)?.boolValue ?? false
        shiftDate = date
        shiftType = text(.shiftType) ?? AdminMemberShiftType.full.rawValue
        notes = text(.notes)
    }

    /// Il giorno come data (mezzanotte locale); `nil` se il testo non è una data.
    var date: Date? { AdminMemberDay.date(from: shiftDate) }

    var dateText: String {
        date?.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) ?? shiftDate
    }

    var teamTitle: String { teamName ?? String(localized: "Unnamed team") }

    var typeLabel: String { AdminMemberShiftType.label(shiftType) }
}

/// Un team in cui si può assegnare un turno (GET /v1/teams, solo i campi che servono).
nonisolated struct AdminMemberTeamOption: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let isAdHoc: Bool

    private enum CodingKeys: String, CodingKey { case id, name, isAdHoc }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = AdminMemberText.clean(try? c.decodeIfPresent(String.self, forKey: .id)) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Team without id"))
        }
        self.id = id
        let rawName = AdminMemberText.clean(try? c.decodeIfPresent(String.self, forKey: .name))
        name = rawName ?? String(localized: "Unnamed team")
        isAdHoc = (try? c.decode(Bool.self, forKey: .isAdHoc)) ?? false
    }
}
