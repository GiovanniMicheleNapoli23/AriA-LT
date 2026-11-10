//
//  AriaOnboardingAudienceCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Una delle due scelte della prima schermata (tecnico o admin): un pannello di vetro sullo sfondo del login,
//  col ruolo, cosa si vedrà e una freccia in un cerchio navy.
//

import SwiftUI

struct AriaOnboardingAudienceCard: View {
    let audience: AriaOnboardingAudience
    let action: () -> Void

    @ScaledMetric(relativeTo: .title2) private var arrowSide: CGFloat = 36

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 26, style: .continuous) }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text(audience.title)
                            .font(.title2.weight(.regular))
                            .foregroundStyle(Color.liteText)
                    } icon: {
                        Image(systemName: audience.symbol)
                            .font(.title3)
                            .foregroundStyle(Color.liteAccent)
                    }

                    Text(audience.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)

                Spacer(minLength: 4)

                Image(systemName: "arrow.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.liteOnAccent)
                    .frame(width: arrowSide, height: arrowSide)
                    .background(Color.liteAccent, in: Circle())
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ariaGlass(in: shape, interactive: true)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("onboarding.audience.\(audience.rawValue)")
    }
}
