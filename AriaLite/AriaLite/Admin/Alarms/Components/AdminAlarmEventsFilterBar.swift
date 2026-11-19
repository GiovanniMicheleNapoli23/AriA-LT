//
//  AdminAlarmEventsFilterBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  I tre filtri dell'inbox (All, Unread, Read) come controllo segmentato.
//

import SwiftUI

struct AdminAlarmEventsFilterBar: View {
    let viewModel: AdminAlarmEventsViewModel

    var body: some View {
        Picker("Show", selection: Binding(get: { viewModel.filter }, set: { viewModel.selectFilter($0) })) {
            ForEach(AdminAlarmEventFilter.allCases) { filter in
                Text(filter.label).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }
}
