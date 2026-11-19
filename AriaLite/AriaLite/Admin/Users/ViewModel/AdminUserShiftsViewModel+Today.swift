//
//  AdminUserShiftsViewModel+Today.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda Oggi (§4.1): dove si trova la persona e "Sposta in un team oggi". Scegliere un team manda subito
//  POST /v1/member-assignments con la data UTC di oggi e il turno scelto sopra.
//

import Foundation

extension AdminUserShiftsViewModel {
    /// Dove si trova oggi: il team e, se c'è, il turno.
    struct Placement: Equatable {
        let team: String
        let shift: String?
        let isAdHoc: Bool
    }

    func placement(of details: AdminMember) -> Placement? {
        guard let team = details.currentTeam else { return nil }
        return Placement(
            team: team.name.isEmpty ? String(localized: "Unnamed team") : team.name,
            shift: details.currentShift.map(AdminMemberShiftType.label),
            isAdHoc: team.isAdHoc
        )
    }

    func title(of team: AdminMemberHomeTeam) -> String {
        team.teamName.isEmpty ? String(localized: "Unnamed team") : team.teamName
    }

    /// Il turno di partenza è quello di oggi della persona, se è uno dei quattro; altrimenti `full`. Non si
    /// riscrive una scelta già fatta.
    func seedMoveShift(from currentShift: String?) {
        guard !moveShiftTouched else { return }
        moveShift = currentShift.flatMap { AdminMemberShiftType(rawValue: $0.lowercased()) } ?? .full
    }

    func chooseMoveShift(_ shift: AdminMemberShiftType) {
        moveShiftTouched = true
        moveShift = shift
    }

    func moveToday(to team: AdminMemberTeamOption) async {
        guard canAssignShifts, !isMoving else { return }
        isMoving = true
        defer { isMoving = false }
        let shift = moveShift
        guard await assign(team: team, date: AdminMemberDay.utcToday(), shift: shift,
                           failure: String(localized: "Assignment failed")) else { return }
        owner.show(String(localized: "Assigned to \(team.name) (\(shift.localized))"))
        await reloadDetails()
        await loadHistory()
    }
}
