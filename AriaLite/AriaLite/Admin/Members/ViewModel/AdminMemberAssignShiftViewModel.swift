//
//  AdminMemberAssignShiftViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il modulo "Assign shift": team, giorno, tipo di turno e note (POST /v1/member-assignments). La risposta
//  non si legge: finito il salvataggio il dettaglio rilegge i turni.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminMemberAssignShiftViewModel: Identifiable {
    let member: AdminMember
    let owner: AdminMemberDetailViewModel
    private var members: AdminMembersViewModel { owner.owner }

    // MARK: - Campi

    var teamId: String?
    /// Il team di partenza, per capire se l'utente ha toccato qualcosa.
    private var initialTeamId: String?
    var date = Calendar.current.startOfDay(for: .now)
    var shiftType: AdminMemberShiftType = .full
    var notes = ""

    private(set) var isSaving = false
    private(set) var errorMessage: String?

    init(member: AdminMember, owner: AdminMemberDetailViewModel) {
        self.member = member
        self.owner = owner
        // Un team di partenza sensato: quello di appartenenza, se ce n'è uno solo.
        if member.homeTeams.count == 1 { teamId = member.homeTeams.first?.teamId }
        initialTeamId = teamId
    }

    // MARK: - Presentazione

    var teams: [AdminMemberTeamOption] { members.teams }

    var isLoadingTeams: Bool { members.isLoadingTeams && teams.isEmpty }

    var teamsError: String? { teams.isEmpty ? members.teamsFailure?.message : nil }

    /// Il team scelto non è (più) fra quelli scaricati: si tiene comunque scelto finché non ne arriva un altro.
    var canSave: Bool { !isSaving && teamId != nil }

    var hasChanges: Bool { teamId != initialTeamId || !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var today: Date { Calendar.current.startOfDay(for: .now) }

    func loadTeams() async {
        await members.loadTeamsIfNeeded()
    }

    // MARK: - Salvataggio

    /// `true` se salvato: il modulo si può chiudere.
    func save() async -> Bool {
        guard !isSaving, let teamId else { return false }
        errorMessage = nil
        let notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = AdminMemberAssignmentCreate(
            userId: member.id, teamId: teamId, shiftDate: AdminMemberDay.string(from: date),
            shiftType: shiftType.rawValue, notes: notes.isEmpty ? nil : notes
        )
        isSaving = true
        defer { isSaving = false }
        do {
            try await AdminMembersAPI(api: members.backend.api).assign(body)
        } catch {
            if let failure = AdminMembersFailure.from(error, action: .write, backend: members.backend) {
                errorMessage = failure.message
            }
            return false
        }
        await owner.didAssign()
        return true
    }
}
