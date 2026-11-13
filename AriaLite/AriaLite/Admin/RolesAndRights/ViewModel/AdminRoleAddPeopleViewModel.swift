//
//  AdminRoleAddPeopleViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  "Aggiungi persone a {ruolo}": chi il server permette di spostare, senza chi ha già il ruolo, cercato per nome.
//  Un tocco dà il ruolo e la schermata resta aperta per aggiungerne altri.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminRoleAddPeopleViewModel: Identifiable {
    let roleId: String
    let owner: AdminRolesViewModel
    var query = ""

    var id: String { roleId }

    init(roleId: String, owner: AdminRolesViewModel) {
        self.roleId = roleId
        self.owner = owner
    }

    var role: AdminRole? { owner.role(id: roleId) }
    var roleName: String { role?.name ?? "" }

    enum State: Equatable {
        case loading
        case failed
        case empty
        case loaded([AdminRoleCandidate])
    }

    var state: State {
        switch owner.candidates {
        case nil, .loading?: return .loading
        case .failed?: return .failed
        case .loaded(let all)?:
            var held: Set<String> = []
            if case .loaded(let list)? = owner.holders[roleId] { held = Set(list.map(\.userId)) }
            let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let shown = all.filter { candidate in
                candidate.role?.id != roleId && !held.contains(candidate.userId)
                    && (q.isEmpty || (candidate.name ?? "").localizedCaseInsensitiveContains(q))
            }
            return shown.isEmpty ? .empty : .loaded(shown)
        }
    }

    func load() async { await owner.loadCandidates() }

    func name(_ candidate: AdminRoleCandidate) -> String {
        candidate.name.flatMap { $0.isEmpty ? nil : $0 } ?? String(localized: "Unnamed person")
    }

    /// Il ruolo che ha ora, o "serve un ruolo".
    func currentRole(_ candidate: AdminRoleCandidate) -> String {
        candidate.role?.name ?? String(localized: "needs a role")
    }

    func isBusy(_ candidate: AdminRoleCandidate) -> Bool { owner.busyPeople.contains(candidate.userId) }

    func add(_ candidate: AdminRoleCandidate) async {
        guard let role else { return }
        await owner.assign(userId: candidate.userId, name: candidate.name, to: role)
    }
}
