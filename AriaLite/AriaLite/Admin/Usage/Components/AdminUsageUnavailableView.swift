//
//  AdminUsageUnavailableView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  "Usage figures are unavailable right now" (contratto 4): il cruscotto è fallito, è disattivato o senza periodo. Nessuna
//  cifra; "Retry" e, su un ciclo passato, "Back to the current cycle". Nello stile di `AriaUsageErrorView`.
//

import SwiftUI

struct AdminUsageUnavailableView: View {
    let isOnPastCycle: Bool
    let retry: () -> Void
    let back: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(Color.liteWarning)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Usage figures are unavailable right now").font(.headline)
                Text("Chat, agents and workflows keep working as usual. Try again in a few minutes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { buttons }
                VStack(alignment: .leading, spacing: 8) { buttons }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.liteSurface, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var buttons: some View {
        Button(action: retry) { Label("Retry", systemImage: "arrow.clockwise") }
            .buttonStyle(.bordered)
            .controlSize(.large)
        if isOnPastCycle {
            Button(action: back) { Text("Back to the current cycle") }
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
    }
}
