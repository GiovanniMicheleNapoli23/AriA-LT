//
//  AdminMobileUserPickerViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il foglio "Add existing user": gli utenti attivi dell'azienda (GET /v1/users) che non sono già operatori,
//  con ricerca. Scegliere una riga li promuove (POST …/mobile-users {userId}) e occupa un posto.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminMobileUserPickerViewModel: Identifiable {
    let list: AdminMobileUsersViewModel

    private(set) var candidates: [AdminMobileUserCandidate] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    /// L'utente che si sta promuovendo (la riga mostra l'attesa).
    private(set) var addingId: String?
    var searchText = ""

    init(list: AdminMobileUsersViewModel) {
        self.list = list
    }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Attivi, con un id, non ancora operatori; in ordine di nome.
    var visibleCandidates: [AdminMobileUserCandidate] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let ids = list.existingIds
        let emails = list.existingEmails
        return candidates
            .filter { $0.isActive && $0.userId != nil }
            .filter { !ids.contains($0.userId ?? "") && !emails.contains($0.email.lowercased()) }
            .filter { query.isEmpty || [$0.displayName, $0.email].contains { $0.localizedStandardContains(query) } }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    func subtitle(for candidate: AdminMobileUserCandidate) -> String {
        [candidate.role?.capitalized, candidate.fullName == nil ? nil : candidate.email]
            .compactMap { $0 }.joined(separator: " · ")
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            candidates = try await list.backend.api.call(AdminMobileUsersAPI.users()).items
            hasLoaded = true
            errorMessage = nil
        } catch {
            if let message = AdminMobileUserFailure.message(for: error, backend: list.backend) {
                errorMessage = message
            }
        }
    }

    /// Promuove l'utente. Dice se è andata, per chiudere il foglio; l'errore resta nel foglio.
    func add(_ candidate: AdminMobileUserCandidate) async -> Bool {
        guard let userId = candidate.userId, let companyId = list.backend.activeCompanyId,
              addingId == nil else { return false }
        addingId = userId
        errorMessage = nil
        defer { addingId = nil }
        do {
            let user = try await list.backend.api.call(
                AdminMobileUsersAPI.add(companyId: companyId, AdminMobileUserAdd(userId: userId)))
            await list.didAdd(user)
            return true
        } catch {
            errorMessage = AdminMobileUserFailure.message(for: error, backend: list.backend)
            return false
        }
    }
}
