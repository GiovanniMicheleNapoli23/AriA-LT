//
//  AdminUserShiftDay.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Un giorno della cronologia di una persona (§4.3): i turni con la stessa `shift_date`, in ordine di arrivo.
//

import Foundation

nonisolated struct AdminUserShiftDay: Identifiable, Equatable, Sendable {
    /// `YYYY-MM-DD`.
    let date: String
    let shifts: [AdminMemberShift]

    var id: String { date }

    /// "Wed, 18 Nov": il giorno come testo breve; se non è una data, il testo com'è.
    var title: String { shifts.first?.dateText ?? date }

    /// `today` è il giorno UTC di oggi (`AdminMemberDay.utcToday()`): il confronto fra testi ISO è quello fra date.
    func isToday(_ today: String) -> Bool { date == today }

    /// Raggruppa per giorno, il più recente per primo; dentro il giorno l'ordine del server resta.
    static func group(_ shifts: [AdminMemberShift]) -> [AdminUserShiftDay] {
        var order: [String] = []
        var byDate: [String: [AdminMemberShift]] = [:]
        for shift in shifts {
            if byDate[shift.shiftDate] == nil { order.append(shift.shiftDate) }
            byDate[shift.shiftDate, default: []].append(shift)
        }
        return order.sorted(by: >).map { AdminUserShiftDay(date: $0, shifts: byDate[$0] ?? []) }
    }
}
