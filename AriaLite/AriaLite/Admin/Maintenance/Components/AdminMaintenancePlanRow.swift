//
//  AdminMaintenancePlanRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda di un piano nella lista: nome, asset, frequenza e prossima scadenza; a destra scadenza e stato.
//

import SwiftUI

struct AdminMaintenancePlanRow: View {
    let plan: AdminMaintenancePlan

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var iconSide: CGFloat = 40

    private var frequency: AdminMaintenanceFrequency? { AdminMaintenanceFrequency(rawValue: plan.frequency) }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Testo enorme: l'icona ruberebbe spazio al nome.
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: frequency?.systemImage ?? "calendar")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.liteAccent)
                    .frame(width: iconSide, height: iconSide)
                    .background(Color.liteAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(plan.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                if let tag = plan.assetTag {
                    Text(tag)
                        .font(.caption.weight(.bold).monospaced())
                        .foregroundStyle(Color.liteAccent)
                }
                Text(AdminMaintenanceFormat.joined([AdminMaintenanceFormat.schedule(plan), dueText]))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                AdminMaintenanceDueBadge(state: plan.dueState)
                if let status = plan.status { AdminMaintenanceStatusBadge(status: status) }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    private var dueText: String? {
        plan.nextDueAt.map { String(localized: "Due \(AdminMaintenanceFormat.date($0))") }
    }
}
