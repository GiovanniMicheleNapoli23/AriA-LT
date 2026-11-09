//
//  AdminAgentStudioNotificationRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una notifica nella lista: simbolo, titolo, testo, quando; un punto colorato finché non è letta.
//

import SwiftUI

struct AdminAgentStudioNotificationRow: View {
    let notification: AdminAgentStudioNotification

    @ScaledMetric(relativeTo: .caption) private var dotSide: CGFloat = 8

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: notification.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.liteAccent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(notification.title)
                    .font(.subheadline.weight(notification.isRead ? .regular : .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                if let body = notification.body {
                    Text(body)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(4)
                }
                if let date = notification.createdAt {
                    Text(date, format: .relative(presentation: .named))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 8)
            if !notification.isRead {
                Circle()
                    .fill(Color.liteAccent)
                    .frame(width: dotSide, height: dotSide)
                    .padding(.top, 6)
                    .accessibilityLabel(Text("Unread"))
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
