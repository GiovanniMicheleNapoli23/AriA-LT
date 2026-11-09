//
//  AdminAlarmSeverityBadge.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La gravità della diagnosi come capsula. Il testo è quello del server (low, medium, high, critical…),
//  con la prima lettera maiuscola; il colore segue la gravità.
//

import SwiftUI

struct AdminAlarmSeverityBadge: View {
    let severity: String

    var body: some View {
        Label(severity.capitalized, systemImage: "exclamationmark.triangle")
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.12), in: Capsule())
    }

    private var tint: Color {
        switch severity.lowercased() {
        case "critical", "high": .red
        case "medium", "moderate": .orange
        case "low", "minor": .green
        default: .secondary
        }
    }
}
