//
//  AdminTeamAddMemberViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il foglio per aggiungere un membro a una squadra: si cerca fra le persone attive dell'azienda che non ci sono
//  già, si sceglie e si scrive (se serve) il ruolo nella squadra.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminTeamAddMemberViewModel: Identifiable {
    private let detail: AdminTeamDetailViewModel

    var search = ""
    var selectedId: String?
    var role = ""
    private(set) var isSaving = false
    private(set) var errorMessage: String?

    init(detail: AdminTeamDetailViewModel) {
        self.detail = detail
    }

    var title: String { String(localized: "Add member") }

    var isLoadingPeople: Bool { detail.owner.people.isEmpty }

    /// Le persone attive che non sono già nella squadra, filtrate dalla ricerca.
    var choices: [AdminTeamPerson] {
        let already = Set(detail.team.members.compactMap(\.userId))
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return detail.owner.people
            .filter { $0.isActive && !already.contains($0.id) }
            .filter {
                q.isEmpty || $0.displayName.localizedStandardContains(q) || $0.email.localizedStandardContains(q)
            }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    var canSave: Bool { selectedId != nil && !isSaving }

    var hasChanges: Bool { selectedId != nil || !role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func select(_ person: AdminTeamPerson) {
        selectedId = selectedId == person.id ? nil : person.id
    }

    /// `true` se aggiunto: il foglio si può chiudere.
    func save() async -> Bool {
        guard let userId = selectedId, !isSaving else { return false }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        let trimmedRole = role.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let member = try await detail.api.addMember(
                teamId: detail.team.id,
                AdminTeamMemberCreate(userId: userId, roleInTeam: trimmedRole.isEmpty ? nil : trimmedRole))
            await detail.didAdd(member)
            return true
        } catch {
            if let failure = AdminTeamsFailure.from(error, action: .write, backend: detail.owner.backend) {
                errorMessage = failure.message
            }
            return false
        }
    }
}
