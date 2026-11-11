//
//  AdminAssetHealthScore.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Il cuore della scheda di salute: punteggio su 100 in grande, voto e, se c'è, l'etichetta "Critical",
//  con una barra sotto. Verde se buono, arancione altrimenti (mai rosso).
//

import SwiftUI

struct AdminAssetHealthScore: View {
    let health: AdminAssetHealth

    private var tint: Color { health.isHealthy ? .green : .orange }
    private var scoreText: String { health.score.formatted(.number.precision(.fractionLength(0))) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(scoreText)
                    .font(.largeTitle.weight(.bold).monospacedDigit())
                    .foregroundStyle(tint)
                Text(verbatim: "/ 100")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                badges
            }
            ProgressView(value: min(max(health.score, 0), 100), total: 100)
                .tint(tint)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Score \(scoreText) out of 100"))
    }

    private var badges: some View {
        HStack(spacing: 6) {
            if health.isCritical {
                Label("Critical", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15), in: Capsule())
            }
            if !health.grade.isEmpty {
                Text(verbatim: health.grade)
                    .font(.headline)
                    .foregroundStyle(tint)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(tint.opacity(0.15), in: Capsule())
                    .accessibilityLabel(Text("Grade \(health.grade)"))
            }
        }
    }
}
