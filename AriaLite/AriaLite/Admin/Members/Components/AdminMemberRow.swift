//
//  AdminMemberRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Scheda di un membro nella lista: avatar con le iniziali, nome, la riga del ruolo, il badge di stato, dove si
//  trova oggi e il carico. Una persona sospesa in azienda è più spenta (lo dice `access`, non `isActive`).
//

import SwiftUI

struct AdminMemberRow: View {
    let member: AdminMember
    /// La riga sotto il nome ("Owner", "Admin", il ruolo o "Needs a role"), già decisa dal view model.
    let roleLine: String?
    let badge: AdminMemberBadgeKind?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let isAX = dynamicTypeSize.isAccessibilitySize
        let layout = isAX
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            AdminMemberAvatar(initials: member.initials, isActive: !member.isSuspendedInCompany)
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: member.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(member.isSuspendedInCompany ? Color.secondary : Color.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(isAX ? nil : 2)
                if let roleLine {
                    Text(verbatim: roleLine)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(isAX ? nil : 1)
                }
                if let badge { AdminMemberAccessBadge(kind: badge) }
                Label(member.currentSummary ?? String(localized: "Not on shift today"), systemImage: "person.2")
                    .font(.footnote)
                    .foregroundStyle(member.currentSummary == nil ? .tertiary : .secondary)
                    .lineLimit(isAX ? nil : 1)
                if !member.workload.isEmpty { workload }
            }
            if !isAX {
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }

    private var workload: some View {
        HStack(spacing: 6) {
            Text(verbatim: member.workload.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
            if member.workload.overdueCount > 0 {
                Text(verbatim: member.workload.overdueText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
    }
}
