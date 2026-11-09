//
//  AdminConnectorGrantRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La connessione di un membro: account, data e stato, con "Revoke" a destra.
//

import SwiftUI

struct AdminConnectorGrantRow: View {
    let grant: AdminConnectorGrant
    let isRevoking: Bool
    let onRevoke: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                info
                Spacer(minLength: 8)
                revoke
            }
            VStack(alignment: .leading, spacing: 8) {
                info
                revoke
            }
        }
        .padding(.vertical, 8)
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(grant.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)
            HStack(spacing: 6) {
                AdminConnectorStatusBadge(status: grant.status)
                if let date = grant.connectedAt {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let error = grant.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
        }
    }

    @ViewBuilder
    private var revoke: some View {
        if isRevoking {
            ProgressView()
        } else {
            Button("Revoke", role: .destructive, action: onRevoke)
                .font(.footnote.weight(.semibold))
                .buttonStyle(.borderless)
        }
    }
}
