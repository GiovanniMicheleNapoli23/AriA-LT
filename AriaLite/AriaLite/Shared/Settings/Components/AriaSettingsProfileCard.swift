//
//  AriaSettingsProfileCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  Chi è entrato, in cima al profilo: avatar con le iniziali, nome, email e ruolo in una scheda compatta.
//  Con il testo molto grande l'avatar va sopra e il testo prende tutta la larghezza.
//

import SwiftUI

struct AriaSettingsProfileCard: View {
    let initials: String
    let name: String
    let email: String?
    let roleLabel: String
    let roleSymbol: String
    let isAdmin: Bool

    @ScaledMetric(relativeTo: .title) private var avatarSide: CGFloat = 60

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                avatar
                details(alignment: .leading)
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 12) {
                avatar
                details(alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.liteSurface, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }

    private var avatar: some View {
        Text(verbatim: initials)
            .font(.system(.title2, design: .rounded, weight: .semibold))
            .foregroundStyle(Color.liteAccent)
            .frame(width: avatarSide, height: avatarSide)
            .ariaGlass(in: Circle())
            .accessibilityHidden(true)
    }

    private func details(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 6) {
            VStack(alignment: alignment, spacing: 2) {
                Text(verbatim: name)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if let email {
                    Text(verbatim: email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }
            Label(roleLabel, systemImage: roleSymbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isAdmin ? Color.liteOnAccent : Color.liteAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isAdmin ? Color.liteAccent : Color.liteAccent.opacity(0.1), in: Capsule())
        }
    }
}
