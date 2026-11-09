//
//  AdminAlarmApproveBanner.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Per una bozza: un avviso con "Approve". La conferma e la chiamata sono nel view model del dettaglio.
//

import SwiftUI

struct AdminAlarmApproveBanner: View {
    let isApproving: Bool
    let approve: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Waiting for review", systemImage: "clock.badge.questionmark")
                .font(.subheadline.weight(.semibold))
            Text("Approve this alarm to add it to the knowledge base the assistant draws on.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if isApproving {
                ProgressView()
            } else {
                Button(action: approve) {
                    Label("Approve", systemImage: "checkmark.seal")
                }
                .ariaAccentGlassButtonStyle()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}
