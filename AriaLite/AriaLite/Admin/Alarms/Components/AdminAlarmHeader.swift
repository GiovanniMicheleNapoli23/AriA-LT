//
//  AdminAlarmHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'intestazione del dettaglio: codice, stato e descrizione.
//

import SwiftUI

struct AdminAlarmHeader: View {
    let alarm: AdminAlarm

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: alarm.code)
                .font(.title3.weight(.bold).monospaced())
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            AdminAlarmStatusBadge(alarm: alarm)
            if !alarm.description.isEmpty {
                Text(verbatim: alarm.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
