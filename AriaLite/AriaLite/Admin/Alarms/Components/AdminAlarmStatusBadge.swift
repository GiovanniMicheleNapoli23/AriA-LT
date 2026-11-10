//
//  AdminAlarmStatusBadge.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo stato di un allarme come capsula: icona e testo (il colore da solo non basta), e un colore per stato
//  (in attesa di revisione in ambra, approvato nel colore dell'app, scartato o sostituito in grigio).
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
        // Positivo nel colore dell'app, negativo in grigio: il rosso resta per gli errori.
        case .approved?: .liteAccent
        case .draft?, .staged?: .liteWarning
        case .rejected?, .superseded?, nil: .secondary
        }
    }
}
