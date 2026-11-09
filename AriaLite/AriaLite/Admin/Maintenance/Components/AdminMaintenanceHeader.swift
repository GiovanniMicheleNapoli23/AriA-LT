//
//  AdminMaintenanceHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'intestazione del dettaglio: icona della frequenza, asset, nome, stato e scadenza, dove si trova.
//

import SwiftUI

struct AdminMaintenanceHeader: View {
    let plan: AdminMaintenancePlan
    /// Zona, stabilimento e categoria in una riga.
    let place: String

    @ScaledMetric(relativeTo: .title3) private var iconSide: CGFloat = 52

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: AdminMaintenanceFrequency(rawValue: plan.frequency)?.systemImage ?? "calendar")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.liteAccent)
                .frame(width: iconSide, height: iconSide)
                .background(Color.liteAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                if let tag = plan.assetTag {
                    Text(tag)
                        .font(.subheadline.weight(.bold).monospaced())
                        .foregroundStyle(Color.liteAccent)
                        .textSelection(.enabled)
                }
                Text(plan.name)
                    .font(.title3.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                HStack(spacing: 6) {
                    if let status = plan.status { AdminMaintenanceStatusBadge(status: status) }
                    AdminMaintenanceDueBadge(state: plan.dueState)
                }
                if !place.isEmpty {
                    Text(place)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
