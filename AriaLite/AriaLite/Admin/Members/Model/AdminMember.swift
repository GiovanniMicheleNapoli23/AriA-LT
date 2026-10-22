//
//  AdminMember.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un membro come lo manda il backend (MemberResponse). Lettura tollerante: è obbligatorio solo `id`
//  (nell'OpenAPI è facoltativo, ma senza non si apre il dettaglio); il resto illeggibile vale come assente.
//

import Foundation

nonisolated struct AdminMember: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    var email: String
    var fullName: String?
    /// Testo libero (l'OpenAPI non ha un elenco): si mostra com'è.
    var role: String?
    var isActive: Bool
    var avatarUrl: String?
    var specialties: [String]
    var currentTeam: AdminMemberCurrentTeam?
    /// Il tipo di turno di oggi, come lo manda il server (`full`, `morning`...).
    var currentShift: String?
    var workload: AdminMemberWorkload
    var homeTeams: [AdminMemberHomeTeam]

    private enum CodingKeys: String, CodingKey {
        case id, email, fullName, role, isActive, avatarUrl, specialties, currentTeam, currentShift, workload, homeTeams
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func json(_ key: CodingKeys) -> AriaJSON? { try? c.decodeIfPresent(AriaJSON.self, forKey: key) }
        func text(_ key: CodingKeys) -> String? { json(key)?.nonEmptyString }
        guard let id = text(.id) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Member without id"))
        }
        self.id = id
        email = text(.email) ?? ""
        fullName = text(.fullName)
        role = text(.role)
        isActive = json(.isActive)?.boolValue ?? true
        avatarUrl = text(.avatarUrl)
        specialties = (json(.specialties)?.arrayValue ?? []).compactMap(\.nonEmptyString)
        currentTeam = try? c.decodeIfPresent(AdminMemberCurrentTeam.self, forKey: .currentTeam)
        currentShift = text(.currentShift)
        workload = (try? c.decodeIfPresent(AdminMemberWorkload.self, forKey: .workload)) ?? AdminMemberWorkload()
        homeTeams = (try? c.decodeIfPresent(AriaLossyArray<AdminMemberHomeTeam>.self, forKey: .homeTeams))?.items ?? []
    }

    // MARK: - Presentazione

    /// Il nome da mostrare: senza nome, l'email.
    var displayName: String { fullName ?? (email.isEmpty ? String(localized: "Unnamed member") : email) }

    /// Il nome solo se l'email dice qualcosa in più (per la riga sotto il titolo).
    var secondaryLine: String? { fullName != nil && !email.isEmpty ? email : nil }

    /// Le iniziali per l'avatar: due lettere dal nome (o dall'inizio dell'email).
    var initials: String {
        let words = displayName.split { !$0.isLetter && !$0.isNumber }
        let letters = words.count >= 2 ? words.prefix(2).compactMap(\.first) : Array(words.first?.prefix(2) ?? "?")
        return String(letters).uppercased()
    }

    var roleLabel: String? { role.map(AdminMemberRole.label) }

    /// Dove si trova oggi: "Team A · Morning"; `nil` se non è in turno.
    var currentSummary: String? {
        var parts: [String] = []
        if let team = currentTeam, !team.name.isEmpty { parts.append(team.name) }
        if let shift = currentShift { parts.append(AdminMemberShiftType.label(shift)) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Le chiavi dei team in cui compare (di oggi o di appartenenza), per il filtro per team.
    var teamIds: Set<String> {
        Set(homeTeams.map(\.teamId)).union(currentTeam.map { [$0.id] } ?? [])
    }
}
