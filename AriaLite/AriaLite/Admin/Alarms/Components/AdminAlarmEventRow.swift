//
//  AdminAlarmEventRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Scheda di un evento di allarme nell'inbox: codice e gravità in alto, descrizione, poi origine e quanto è
//  passato. Un evento non letto ha un punto del colore d'accento e il codice in semibold.
//

import SwiftUI

struct AdminAlarmEventRow: View {
    let event: AdminAlarmEvent

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var dotSide: CGFloat = 9

    var body: some View {
        // Testo molto grande: le righe vanno in colonna invece di spezzarsi a metà parola.
        let isAX = dynamicTypeSize.isAccessibilitySize
        let line = isAX
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(event.isRead ? Color.clear : Color.liteAccent)
                .frame(width: dotSide, height: dotSide)
                .padding(.top, 6)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                line {
                    Text(verbatim: event.alarmCode)
                        .font(.subheadline.monospaced().weight(event.isRead ? .regular : .semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    if !isAX { Spacer(minLength: 8) }
                    AdminAlarmEventSeverityBadge(severity: event.severity)
                }
                if let description = event.alarmDescription {
                    Text(verbatim: description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(isAX ? nil : 2)
                }
                line {
                    Label(event.source, systemImage: "antenna.radiowaves.left.and.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if !isAX { Spacer(minLength: 8) }
                    if let created = event.createdAt {
                        Text(created, format: .relative(presentation: .named))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityValue(event.isRead ? Text("") : Text("Unread"))
    }
}
