//
//  AdminMobileUserRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda di un operatore nella lista: nome, email, stato, disponibilità e quanti ordini aperti ha.
//  Tutto il testo arriva già pronto dal view model.
//

import SwiftUI

struct AdminMobileUserRow: View {
    let user: AdminMobileUser
    let workLoad: String
    var isBusy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(user.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if isBusy {
                    ProgressView().controlSize(.small)
                } else {
                    AdminMobileUserStatusBadge(status: user.status)
                }
            }
            HStack(spacing: 10) {
                if user.knownStatus == .active {
                    AdminMobileUserAvailabilityLabel(availability: user.availability)
                }
                Label(workLoad, systemImage: "wrench.and.screwdriver")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if !user.specialties.isEmpty {
                Text(user.specialties.joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
        .opacity(isBusy ? 0.6 : 1)
    }
}
