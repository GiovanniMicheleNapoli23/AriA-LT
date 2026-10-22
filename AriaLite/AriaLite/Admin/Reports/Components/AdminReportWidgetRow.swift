//
//  AdminReportWidgetRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una riga dei widget salvati: tipo, titolo e descrizione, un tocco per riaprirlo con i dati di oggi e un
//  menu per eliminarlo.
//

import SwiftUI

struct AdminReportWidgetRow: View {
    let widget: AdminCraftedWidget
    let canDelete: Bool
    let onDelete: () -> Void

    @ScaledMetric(relativeTo: .headline) private var iconSize: CGFloat = 34

    var body: some View {
        HStack(spacing: 8) {
            NavigationLink(value: widget) {
                HStack(spacing: 12) {
                    Image(systemName: AdminCraftedKind.systemImage(widget.kind))
                        .font(.headline)
                        .foregroundStyle(Color.liteAccent)
                        .frame(width: iconSize, height: iconSize)
                        .background(Color.liteAccent.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(widget.displayTitle)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Text(widget.description ?? AdminCraftedKind.label(widget.kind))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(widget.serverId == nil)
            Menu {
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                    .disabled(!canDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
            .accessibilityLabel("More actions")
        }
        .padding(.vertical, 6)
    }
}
