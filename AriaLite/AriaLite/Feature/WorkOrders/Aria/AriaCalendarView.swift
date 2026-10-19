//
//  AriaCalendarView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 17/10/26.
//
//  Il calendario delle task dell'account Aria: un mese con un puntino per ogni lavoro del giorno
//  (rosso se in ritardo, verde se chiuso) e sotto le task del giorno scelto, le stesse schede della lista
//  Tasks. Un lavoro sta nel giorno in cui è programmato; senza data programmata, in quello di scadenza.
//

import SwiftUI

struct AriaCalendarView: View {
    let store: AriaWorkOrderStore

    @State private var month = Calendar.current.startOfMonth(for: .now)
    @State private var selected = Calendar.current.startOfDay(for: .now)

    private var calendar: Calendar { .current }

    /// Aperti e chiusi insieme, per giorno. Senza nessuna data un lavoro non ha un posto nel calendario.
    private var ordersByDay: [Date: [AriaWorkOrder]] {
        var seen = Set<String>()
        let all = (store.orders + store.closedOrders).filter { seen.insert($0.id).inserted }
        let grouped = Dictionary(grouping: all.compactMap { order -> (Date, AriaWorkOrder)? in
            guard let date = order.scheduledDate ?? order.dueDate else { return nil }
            return (calendar.startOfDay(for: date), order)
        }, by: \.0)
        return grouped.mapValues { pairs in
            pairs.map(\.1).sorted {
                ($0.scheduledDate ?? $0.dueDate ?? .distantPast) < ($1.scheduledDate ?? $1.dueDate ?? .distantPast)
            }
        }
    }

    var body: some View {
        NavigationStack {
            let byDay = ordersByDay
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    monthCard(byDay)
                    dayList(byDay[selected] ?? [])
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .refreshable { await store.refresh() }
            .liteBackground()
            .navigationTitle("Calendar")
            .navigationDestination(for: AriaWorkOrder.self) { order in
                AriaWorkOrderDetailView(order: order, store: store)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Today") { goToToday() }
                        .disabled(calendar.isDateInToday(selected) && calendar.isDate(month, equalTo: .now, toGranularity: .month))
                }
            }
        }
    }

    // MARK: Mese

    private func monthCard(_ byDay: [Date: [AriaWorkOrder]]) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.title3.weight(.bold))
                    .contentTransition(.numericText())
                Spacer()
                HStack(spacing: 4) {
                    monthButton("chevron.left", by: -1)
                    monthButton("chevron.right", by: 1)
                }
            }

            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            let weeks = days(of: month).chunked(into: 7)
            VStack(spacing: 4) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 0) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                            if let day { dayCell(day, orders: byDay[day] ?? []) } else { Color.clear.frame(maxWidth: .infinity, minHeight: 46) }
                        }
                    }
                }
            }
        }
        .padding(16)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 20))
        // Un trascinamento orizzontale cambia mese, come sfogliare.
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                    shiftMonth(value.translation.width < 0 ? 1 : -1)
                }
        )
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func monthButton(_ icon: String, by delta: Int) -> some View {
        Button { shiftMonth(delta) } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.liteAccent)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(delta < 0 ? "Previous" : "Next"))
    }

    private func dayCell(_ day: Date, orders: [AriaWorkOrder]) -> some View {
        let isSelected = day == selected
        let isToday = calendar.isDateInToday(day)
        return Button {
            withAnimation(.snappy(duration: 0.2)) { selected = day }
        } label: {
            VStack(spacing: 4) {
                Text(verbatim: "\(calendar.component(.day, from: day))")
                    .font(.system(size: 16, weight: isToday || isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? Color.white : isToday ? Color.liteAccent : Color.primary)
                    .frame(width: 34, height: 34)
                    .background {
                        if isSelected {
                            Circle().fill(Color.liteAccent)
                        } else if isToday {
                            Circle().strokeBorder(Color.liteAccent.opacity(0.5), lineWidth: 1.5)
                        }
                    }
                HStack(spacing: 3) {
                    ForEach(Array(orders.prefix(3).enumerated()), id: \.offset) { _, order in
                        Circle().fill(dotColor(order)).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(day.formatted(date: .complete, time: .omitted)))
        .accessibilityValue(orders.isEmpty ? Text("") : Text("\(orders.count) scheduled tasks"))
    }

    private func dotColor(_ order: AriaWorkOrder) -> Color {
        if order.isClosed { return .green }
        return order.isOverdue ? .red : Color.liteAccent
    }

    // MARK: Giorno

    @ViewBuilder
    private func dayList(_ orders: [AriaWorkOrder]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(selected.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.headline)
                if !orders.isEmpty {
                    Text("\(orders.count) scheduled tasks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if orders.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "tray").foregroundStyle(.tertiary)
                    Text("No tasks on this day").font(.subheadline).foregroundStyle(.tertiary)
                }
                .padding(.vertical, 8)
            } else {
                ForEach(orders) { order in
                    NavigationLink(value: order) {
                        AriaWorkOrderRow(order: order).opacity(order.isClosed ? 0.6 : 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Date

    /// L'inizio della settimana segue la lingua del telefono (lunedì in Italia, domenica negli Stati Uniti).
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// I giorni del mese in settimane intere: `nil` dove la riga comincia o finisce fuori dal mese.
    private func days(of month: Date) -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = calendar.component(.weekday, from: month)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        cells += range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: month) }
        cells += Array(repeating: nil, count: (7 - cells.count % 7) % 7)
        return cells
    }

    private func shiftMonth(_ delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: month) else { return }
        withAnimation(.snappy) {
            month = next
            // Il giorno scelto segue il mese: stesso numero, oppure l'ultimo giorno che esiste.
            let day = calendar.component(.day, from: selected)
            let last = calendar.range(of: .day, in: .month, for: next)?.count ?? day
            selected = calendar.date(byAdding: .day, value: min(day, last) - 1, to: next) ?? next
        }
    }

    private func goToToday() {
        withAnimation(.snappy) {
            month = calendar.startOfMonth(for: .now)
            selected = calendar.startOfDay(for: .now)
        }
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? startOfDay(for: date)
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
