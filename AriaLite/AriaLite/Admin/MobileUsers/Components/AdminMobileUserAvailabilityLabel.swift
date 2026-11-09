//
//  AdminMobileUserAvailabilityLabel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La disponibilità di un operatore (libero, occupato, fuori turno) con un pallino colorato.
//

import SwiftUI

struct AdminMobileUserAvailabilityLabel: View {
    let availability: String

    private var color: Color {
        switch AdminMobileUserAvailability(rawValue: availability) {
        case .available: .green
        case .busy: .orange
        case .offDuty, nil: .secondary
        }
    }

    var body: some View {
        Label {
            Text(AdminMobileUserAvailability.label(for: availability))
        } icon: {
            Image(systemName: AdminMobileUserAvailability(rawValue: availability)?.systemImage ?? "circle")
                .foregroundStyle(color)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
