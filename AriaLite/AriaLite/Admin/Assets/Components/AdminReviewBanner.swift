//
//  AdminReviewBanner.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  La revisione di un asset, un allarme, un ricambio o un piano: lo stato ("Waiting for review", "Approved",
//  "Rejected") e cosa vuol dire. Le decisioni sono nella barra in basso (AdminReviewDecisionBar).
//

import SwiftUI

struct AdminReviewBanner: View {
    let stage: AdminReviewStage
    let message: LocalizedStringKey

    @ScaledMetric(relativeTo: .subheadline) private var iconSide: CGFloat = 36

    private var tone: Color {
        switch stage {
        case .pending: .liteWarning
        case .approved: .liteAccent
        case .rejected: .secondary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: stage.systemImage)
                .font(.headline)
                .foregroundStyle(tone)
                .frame(width: iconSide, height: iconSide)
                .background(tone.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(stage.title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}
