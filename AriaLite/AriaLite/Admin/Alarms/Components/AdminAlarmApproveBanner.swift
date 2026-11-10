//
//  AdminAlarmApproveBanner.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Per una bozza: un avviso con "Approve" a tutta larghezza. La conferma e la chiamata sono nel view model
//  del dettaglio.
//

import SwiftUI

struct AdminAlarmApproveBanner: View {
    let isApproving: Bool
    let approve: () -> Void

    @ScaledMetric(relativeTo: .subheadline) private var iconSide: CGFloat = 36

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "clock.badge.questionmark")
                    .font(.headline)
                    .foregroundStyle(Color.liteWarning)
                    .frame(width: iconSide, height: iconSide)
                    .background(Color.liteWarning.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Waiting for review")
                        .font(.subheadline.weight(.semibold))
                    Text("Approve this alarm to add it to the knowledge base the assistant draws on.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            Button(action: approve) {
                Group {
                    if isApproving {
                        ProgressView().tint(Color.liteOnAccent)
                    } else {
                        Label("Approve", systemImage: "checkmark.seal")
                    }
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
            }
            .ariaAccentGlassButtonStyle()
            .disabled(isApproving)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}
