//
//  AdminAuditLogRowView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una riga dello storico: l'icona dell'azione, la frase "chi ha fatto che cosa su che cosa" e l'ora.
//

import SwiftUI

struct AdminAuditLogRowView: View {
    let row: AdminAuditLogRowItem

    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 26

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: row.icon)
                .font(.title3)
                .foregroundStyle(row.tone.color)
                .frame(width: iconWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(row.sentence)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                if let time = row.time {
                    Text(time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}
