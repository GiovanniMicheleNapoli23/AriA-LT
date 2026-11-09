//
//  AdminAlarmStatusBadge.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo stato di un allarme come capsula: icona e testo (il colore da solo non basta), e un colore per stato.
//

import SwiftUI

struct AdminAlarmStatusBadge: View {
    let alarm: AdminAlarm

    var body: some View {
        Label(alarm.statusLabel, systemImage: alarm.status?.systemImage ?? "questionmark.circle")
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.12), in: Capsule())
    }

    private var tint: Color {
        switch alarm.status {
        case .approved?: .green
        case .draft?: .orange
        case .staged?: .blue
        case .rejected?: .red
        case .superseded?, nil: .secondary
        }
    }
}
