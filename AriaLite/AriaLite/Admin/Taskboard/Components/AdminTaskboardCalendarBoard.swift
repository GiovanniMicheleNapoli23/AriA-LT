//
//  AdminTaskboardCalendarBoard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Il calendario della bacheca: il mese e, sotto, le attività del giorno scelto divise per persona.
//  Su iPhone in orizzontale e su schermi larghi il mese sta a sinistra e il giorno accanto, altrimenti il
//  giorno finirebbe sotto la piega.
//

import SwiftUI

struct AdminTaskboardCalendarBoard<CardView: View>: View {
    let viewModel: AdminTaskboardViewModel
    @ViewBuilder var card: (AdminWorkOrderRowItem) -> CardView

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var sideBySide: Bool { horizontalSizeClass == .regular || verticalSizeClass == .compact }

    var body: some View {
        let layout = sideBySide
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 20))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 20))
        layout {
            AdminTaskboardMonthCard(viewModel: viewModel)
                .frame(maxWidth: sideBySide ? 380 : .infinity)
            day
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
    }

    private var day: some View {
        let groups = viewModel.calendarDayGroups
        let count = groups.reduce(0) { $0 + $1.items.count }
        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.calendarDayTitle)
                    .font(.headline)
                    .contentTransition(.numericText())
                if count > 0 {
                    Text("\(count) scheduled tasks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if groups.isEmpty {
                AdminSectionNotice(text: String(localized: "No tasks on this day"), systemImage: "tray")
            }
            ForEach(groups) { group in
                AdminTaskboardPersonSection(group: group, card: card)
            }
        }
    }
}
