//
//  AdminTaskboardViewModel+Calendar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Il calendario della bacheca: un mese con un pallino per ogni lavoro del giorno e, sotto, le attività del
//  giorno scelto divise per persona. Un lavoro sta nel giorno in cui è programmato; senza data programmata, in
//  quello di scadenza; senza nessuna delle due non sta nel calendario. Aperti e chiusi insieme, coi filtri.
//

import Foundation

extension AdminTaskboardViewModel {
    private var calendar: Calendar { .current }

    nonisolated static func startOfMonth(_ date: Date) -> Date {
        Calendar.current.dateInterval(of: .month, for: date)?.start ?? Calendar.current.startOfDay(for: date)
    }

    /// Il giorno di un ordine nel calendario.
    private func calendarDate(of order: AdminWorkOrder) -> Date? {
        (order.scheduledDate ?? order.dueDate).map(calendar.startOfDay)
    }

    // MARK: Mese

    var calendarTitle: String { calendarMonth.formatted(.dateTime.month(.wide).year()) }

    /// L'inizio della settimana segue la lingua del telefono (lunedì in Italia, domenica negli Stati Uniti).
    var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// I giorni del mese in settimane intere: `nil` dove la riga comincia o finisce fuori dal mese.
    var calendarWeeks: [[Date?]] {
        guard let range = calendar.range(of: .day, in: .month, for: calendarMonth) else { return [] }
        let weekday = calendar.component(.weekday, from: calendarMonth)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        cells += range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: calendarMonth) }
        cells += Array(repeating: nil, count: (7 - cells.count % 7) % 7)
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<min($0 + 7, cells.count)]) }
    }

    /// I pallini di ogni giorno del mese a schermo (al più tre): prima i ritardi, poi gli aperti, poi i chiusi.
    var calendarTones: [Date: [AdminTaskboardDayTone]] {
        guard let interval = calendar.dateInterval(of: .month, for: calendarMonth) else { return [:] }
        var tones: [Date: [AdminTaskboardDayTone]] = [:]
        for order in visibleOrders {
            guard let day = calendarDate(of: order), interval.contains(day) else { continue }
            tones[day, default: []].append(order.isClosed ? .closed : order.isOverdue() ? .overdue : .open)
        }
        return tones.mapValues { Array($0.sorted { Self.rank($0) < Self.rank($1) }.prefix(3)) }
    }

    func isToday(_ day: Date) -> Bool { calendar.isDateInToday(day) }

    var isShowingToday: Bool {
        calendar.isDateInToday(calendarDay) && calendar.isDate(calendarMonth, equalTo: .now, toGranularity: .month)
    }

    func dayNumber(_ day: Date) -> String { "\(calendar.component(.day, from: day))" }

    // MARK: Giorno

    var calendarDayTitle: String { calendarDay.formatted(.dateTime.weekday(.wide).day().month(.wide)) }

    /// Le attività del giorno scelto, per persona.
    var calendarDayGroups: [AdminTaskboardPersonGroup] {
        personGroups(visibleOrders.filter { calendarDate(of: $0) == calendarDay })
    }

    // MARK: Azioni

    func selectDay(_ day: Date) { calendarDay = calendar.startOfDay(for: day) }

    /// Cambia mese; il giorno scelto segue: stesso numero, oppure l'ultimo giorno che esiste.
    func shiftMonth(_ delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: calendarMonth) else { return }
        calendarMonth = next
        let day = calendar.component(.day, from: calendarDay)
        let last = calendar.range(of: .day, in: .month, for: next)?.count ?? day
        calendarDay = calendar.date(byAdding: .day, value: min(day, last) - 1, to: next) ?? next
    }

    func goToToday() {
        calendarMonth = Self.startOfMonth(.now)
        calendarDay = calendar.startOfDay(for: .now)
    }

    private static func rank(_ tone: AdminTaskboardDayTone) -> Int {
        switch tone {
        case .overdue: 0
        case .open: 1
        case .closed: 2
        }
    }
}
