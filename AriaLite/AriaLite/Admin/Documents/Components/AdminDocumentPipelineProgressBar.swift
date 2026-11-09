//
//  AdminDocumentPipelineProgressBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  L'avanzamento di una pipeline del documento: una barra sottile con la percentuale e sotto il passo
//  ("Step 3 of 5 · Chunking"). Senza una frazione (stato sconosciuto) resta la sola etichetta con un
//  indicatore di attività. Verde a pipeline conclusa, nel colore dell'app altrimenti.
//

import SwiftUI

struct AdminDocumentPipelineProgressBar: View {
    let progress: AdminDocumentPipelineProgress
    /// Mostra il nome della pipeline davanti al passo (quando ne compaiono due insieme).
    var showsPipeline = false

    @ScaledMetric(relativeTo: .caption) private var barHeight = 6.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tint: Color { progress.isFinished ? .green : .liteAccent }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let fraction = progress.fraction {
                HStack(spacing: 8) {
                    track(fraction: fraction)
                    Text(fraction, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
                caption
            } else {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    caption
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(progress.pipeline.title))
        .accessibilityValue(Text(progress.accessibilityValue))
    }

    private var caption: some View {
        Text(progress.caption(showingPipeline: showsPipeline))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func track(fraction: Double) -> some View {
        Capsule()
            .fill(Color.primary.opacity(0.1))
            .frame(height: barHeight)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(tint)
                        .frame(width: proxy.size.width * fraction)
                        .animation(reduceMotion ? nil : .smooth, value: fraction)
                }
            }
            .clipShape(Capsule())
    }
}
