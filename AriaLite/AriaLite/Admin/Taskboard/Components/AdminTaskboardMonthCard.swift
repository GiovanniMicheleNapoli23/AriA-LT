//
//  AdminTaskboardMonthCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Il mese del calendario della bacheca: titolo con "Today" e frecce, i giorni in settimane con un pallino per
//  lavoro (colore dell'app se aperto, rosso in ritardo, verde chiuso). Un tocco sceglie il giorno, un trascinamento
//  orizzontale sfoglia i mesi. Tutti i conti li fa AdminTaskboardViewModel+Calendar.
//

import SwiftUI

struct AdminTaskboardMonthCard: View {
    let viewModel: AdminTaskboardViewModel

    @ScaledMetric(relativeTo: .footnote) private var monthButtonSide: CGFloat = 36
    /// Il cerchio del giorno cresce col testo, ma non oltre 44pt: sette colonne devono stare in un iPhone.
    @ScaledMetric(relativeTo: .callout) private var scaledDaySide: CGFloat = 34
    private var daySide: CGFloat { min(scaledDaySide, 44) }

    var body: some View {
        let tones = viewModel.calendarTones
        VStack(spacing: 12) {
            HStack(spacing: 4) {
                Text(viewModel.calendarTitle)
                    .font(.title3.weight(.bold))
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                Button("Today") { withAnimation(.snappy) { viewModel.goToToday() } }
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.borderless)
                    .tint(Color.liteAccent)
                    .disabled(viewModel.isShowingToday)
                monthButton("chevron.left", by: -1)
                monthButton("chevron.right", by: 1)
            }

            HStack(spacing: 0) {
                ForEach(Array(viewModel.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            VStack(spacing: 4) {
                ForEach(Array(viewModel.calendarWeeks.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 0) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                            if let day {
                                dayCell(day, tones: tones[day] ?? [])
                            } else {
                                Color.clear.frame(maxWidth: .infinity, minHeight: 46)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        // Sette colonne devono starci anche a 320pt: oltre xxLarge il mese non cresce più (la lista sotto sì).
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 20))
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                    withAnimation(.snappy) { viewModel.shiftMonth(value.translation.width < 0 ? 1 : -1) }
                }
        )
        .sensoryFeedback(.selection, trigger: viewModel.calendarDay)
    }

    private func monthButton(_ icon: String, by delta: Int) -> some View {
        Button { withAnimation(.snappy) { viewModel.shiftMonth(delta) } } label: {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.liteAccent)
                .frame(width: monthButtonSide, height: monthButtonSide)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(delta < 0 ? "Previous" : "Next"))
    }

    private func dayCell(_ day: Date, tones: [AdminTaskboardDayTone]) -> some View {
        let isSelected = day == viewModel.calendarDay
        let isToday = viewModel.isToday(day)
        return Button {
            withAnimation(.snappy(duration: 0.2)) { viewModel.selectDay(day) }
        } label: {
            VStack(spacing: 4) {
                Text(verbatim: viewModel.dayNumber(day))
                    .font(.callout.weight(isToday || isSelected ? .bold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(isSelected ? Color.liteOnAccent : isToday ? Color.liteAccent : Color.primary)
                    .frame(width: daySide, height: daySide)
                    .background {
                        if isSelected {
                            Circle().fill(Color.liteAccent)
                        } else if isToday {
                            Circle().strokeBorder(Color.liteAccent.opacity(0.5), lineWidth: 1.5)
                        }
                    }
                HStack(spacing: 3) {
                    ForEach(Array(tones.enumerated()), id: \.offset) { _, tone in
                        Circle().fill(color(tone)).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(day.formatted(date: .complete, time: .omitted)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func color(_ tone: AdminTaskboardDayTone) -> Color {
        switch tone {
        case .open: Color.liteAccent
        case .overdue: .red
        case .closed: .green
        }
    }
}
