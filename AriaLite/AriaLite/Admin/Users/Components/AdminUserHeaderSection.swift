//
//  AdminUserHeaderSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  L'intestazione della persona: avatar, nome, email, per i titolari il "online", il carico di lavoro e lo stato.
//  Sospeso e invitato sono grigi, mai rossi.
//

import SwiftUI

struct AdminUserHeaderSection: View {
    let viewModel: AdminUserDetailViewModel

    @ScaledMetric(relativeTo: .caption) private var dot: CGFloat = 8

    var body: some View {
        Section {
            if let row = viewModel.row {
                HStack(alignment: .top, spacing: 14) {
                    AdminMemberAvatar(initials: row.initials, isActive: row.status != .suspended, isLarge: true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: row.displayName)
                            .font(.headline)
                        if let email = row.email, !email.isEmpty, email != row.displayName {
                            Text(verbatim: email)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if let online = viewModel.onlineLine {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(online.isOnline ? Color.green : Color.secondary.opacity(0.4))
                                    .frame(width: dot, height: dot)
                                    .accessibilityHidden(true)
                                Text(verbatim: online.text)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let workload = viewModel.workloadText {
                            Text(verbatim: workload)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        AdminMemberBadge(text: viewModel.statusText,
                                         tint: row.status == .active ? Color.liteAccent : Color.secondary)
                            .padding(.top, 2)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
