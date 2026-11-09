//
//  AdminScenarioSectionHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il titoletto maiuscolo sopra una lista ("12 SCENARIOS") e la riga "Updated 10:30" in fondo.
//

import SwiftUI

struct AdminScenarioSectionHeader: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.top, 4)
    }
}

struct AdminScenarioUpdatedFooter: View {
    let date: Date?

    var body: some View {
        if let date {
            Text("Updated \(date.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
        }
    }
}
