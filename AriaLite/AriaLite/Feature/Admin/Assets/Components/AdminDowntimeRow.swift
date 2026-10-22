//
//  AdminDowntimeRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un fermo macchina: periodo, durata, motivo e ordine collegato. Un fermo in corso è in evidenza e ha
//  "Close now" a portata di dito; modifica ed eliminazione stanno nel menu.
//

import SwiftUI

struct AdminDowntimeRow: View {
    let downtime: AdminDowntime
    let workOrderTitle: String?
    let isBusy: Bool
    let onEdit: () -> Void
    let onClose: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: downtime.isOpen ? "exclamationmark.octagon.fill" : "pause.circle")
                .font(.body.weight(.semibold))
                .foregroundStyle(downtime.isOpen ? Color.orange : Color.secondary)
                .frame(width: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if downtime.isOpen {
                        Text("Ongoing")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.14), in: Capsule())
                    }
                    if let duration = downtime.durationText() {
                        Text(duration)
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                    }
                }
                Text(downtime.periodText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let reason = downtime.reason {
                    Text(reason)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let link = workOrderTitle ?? downtime.workOrderId {
                    Label(link, systemImage: "wrench.and.screwdriver")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if downtime.isOpen, downtime.serverId != nil {
                    Button("Close now", systemImage: "stop.circle", action: onClose)
                        .font(.footnote.weight(.semibold))
                        .tint(Color.liteAccent)
                        .disabled(isBusy)
                        .padding(.top, 4)
                }
            }
            Spacer(minLength: 4)
            if isBusy {
                ProgressView()
            } else if downtime.serverId != nil {
                Menu {
                    Button("Edit", systemImage: "pencil", action: onEdit)
                    if downtime.isOpen {
                        Button("Close now", systemImage: "stop.circle", action: onClose)
                    }
                    Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text("Downtime actions"))
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
