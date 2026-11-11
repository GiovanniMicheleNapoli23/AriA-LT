//
//  AdminAlarmEventSeverityBadge.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  La gravità di un evento di allarme come capsula. Il server la manda come numero (default 2): si mostra
//  com'è; da 3 in su è arancione, sotto resta grigia (mai rosso).
//

import SwiftUI

struct AdminAlarmEventSeverityBadge: View {
    let severity: Int

    var body: some View {
        Label("Severity \(severity)", systemImage: "exclamationmark.triangle")
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.12), in: Capsule())
    }

    private var tint: Color { severity >= 3 ? .orange : .secondary }
}
