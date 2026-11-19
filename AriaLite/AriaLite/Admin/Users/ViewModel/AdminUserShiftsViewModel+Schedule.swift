//
//  AdminUserShiftsViewModel+Schedule.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La pagina Pianifica (§4.2): una data (oggi all'inizio), un turno (`full`) e un team; "Schedule" manda lo stesso
//  POST /v1/member-assignments con la data scelta. Sovrascrive la stessa data e lo stesso turno, se ci sono.
//

import Foundation

extension AdminUserShiftsViewModel {
    var canSchedule: Bool { canAssignShifts && scheduleTeam != nil && !isScheduling }

    func chooseScheduleTeam(_ team: AdminMemberTeamOption) {
        scheduleTeam = team
    }

    func schedule() async {
        guard canSchedule, let team = scheduleTeam else { return }
        isScheduling = true
        defer { isScheduling = false }
        let date = scheduleDate
        let shift = scheduleShift
        guard await assign(team: team, date: AdminMemberDay.string(from: date), shift: shift,
                           failure: String(localized: "Scheduling failed")) else { return }
        let dateText = date.formatted(date: .abbreviated, time: .omitted)
        owner.show(String(localized: "Scheduled for \(dateText) (\(shift.localized))"))
        scheduleTeam = nil
        await loadHistory()
        await reloadDetails()
    }
}
