//
//  AriaSignUpPlanCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 11/11/26.
//
//  Il passo Piano: l'unica scelta, la demo gratuita, già selezionata, e il pulsante che chiude l'iscrizione.
//

import SwiftUI

struct AriaSignUpPlanCard: View {
    @Bindable var model: AriaSignUpViewModel
    @ScaledMetric(relativeTo: .body) private var iconSide: CGFloat = 44

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                plan
                Text("Paid plans are coming soon.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }

            LoginPrimaryButton(title: "Start the free demo", isEnabled: model.canFinish, isBusy: model.isSaving) {
                Task { await model.finish() }
            }
        }
    }

    private var plan: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundStyle(Color.liteAccent)
                .frame(width: iconSide, height: iconSide)
                .background(Color.liteAccent.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("Free demo")
                    .font(.headline)
                    .foregroundStyle(Color.liteText)
                Text("Try AriaPLT with your team, free. No payment details needed.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.liteAccent)
        }
        .padding(16)
        .background(Color.liteSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.liteAccent, lineWidth: 1.5)
        }
        .shadow(color: Color.liteAccent.opacity(0.06), radius: 20, x: 0, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isSelected)
    }
}
