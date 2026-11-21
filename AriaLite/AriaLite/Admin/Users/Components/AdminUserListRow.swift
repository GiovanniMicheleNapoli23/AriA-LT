//
//  AdminUserListRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Una persona dell'elenco (§3.2): avatar, nome, badge di livello, stato e disponibilità, la riga "online" (solo
//  per i titolari), l'email e l'icona dell'app. Disegna quel che AdminUserListItem ha già deciso.
//

import SwiftUI

struct AdminUserListRow: View {
    let item: AdminUserListItem

    @ScaledMetric(relativeTo: .footnote) private var dotSize: CGFloat = 8

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AdminMemberAvatar(initials: item.row.initials, isActive: !item.isMuted)
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: item.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(item.isMuted ? Color.secondary : Color.primary)
                    .multilineTextAlignment(.leading)
                AdminMobileUserFlowLayout(spacing: 6) {
                    ForEach(item.badges) { badge in
                        AdminMemberBadge(text: badge.text, tint: tint(badge.tone))
                    }
                }
                if item.showsOnlineLine { onlineLine }
                if let email = item.email, email != item.name {
                    Text(verbatim: email)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 8)
            if item.showsAppMark { appMark }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    /// La riga "online" si riscrive da sola ogni 30 secondi: invalida solo questa riga, non l'elenco.
    private var onlineLine: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            if let line = item.onlineLine(at: context.date) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(line.isOnline ? Color.green : Color.secondary.opacity(0.5))
                        .frame(width: dotSize, height: dotSize)
                        .accessibilityHidden(true)
                    Text(verbatim: line.text)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// L'icona dell'app: accesa se la persona può usarla.
    private var appMark: some View {
        let on = item.row.appAccess
        return Image(systemName: "iphone")
            .font(.subheadline)
            .foregroundStyle(on ? Color.liteAccent : Color.secondary.opacity(0.5))
            .accessibilityLabel(on ? Text("App on") : Text("App off"))
    }

    private func tint(_ tone: AdminUserListItem.Tone) -> Color {
        switch tone {
        case .accent: Color.liteAccent
        case .positive: Color.green
        case .neutral: Color.secondary
        }
    }
}
