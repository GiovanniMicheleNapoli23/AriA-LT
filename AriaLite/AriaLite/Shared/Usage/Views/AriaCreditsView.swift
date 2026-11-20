//
//  AriaCreditsView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La pagina "AI Operational Credits", con un push dalle impostazioni o nel suo foglio (AriaCreditsSheet): la cifra
//  grande, l'eventuale avviso di stato, le ore e il ciclo (o la prova) con le barre, e gli ultimi sette giorni. Se il saldo non si legge: "Can't read your credits"
//  e "Try again". Tira per rileggere. La logica sta in AriaCreditsViewModel.
//

import SwiftUI

struct AriaCreditsView: View {
    let model: AriaCreditsViewModel

    var body: some View {
        ZStack {
            Color.liteBackground.ignoresSafeArea()
            ScrollView {
                content
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .ariaReadableWidth()
            }
            .scrollBounceBehavior(.basedOnSize)
            .refreshable { await model.refresh() }
        }
        .navigationTitle("AI Operational Credits")
        .navigationBarTitleDisplayMode(.inline)
        // Le impostazioni rileggono ogni 60 s; qui una lettura fresca all'apertura.
        .task { await model.refresh() }
    }

    @ViewBuilder
    private var content: some View {
        if let summary = model.summary {
            ready(summary)
        } else if model.state == .failed {
            AriaUsageErrorView(
                title: "Can’t read your credits",
                message: "Chat keeps working. The figures will show again once they load."
            ) { model.retry() }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 120)
        }
    }

    private func ready(_ summary: AriaAllowanceSummary) -> some View {
        let tint = model.tint(summary.tone)
        return VStack(alignment: .leading, spacing: 20) {
            big(summary.big)

            if let alert = summary.alert { alertBox(alert) }

            if summary.window != nil || summary.cycle != nil {
                VStack(alignment: .leading, spacing: 20) {
                    if let window = summary.window { AriaCreditsBar(content: model.windowBar(window), tint: tint) }
                    if let cycle = summary.cycle { AriaCreditsBar(content: model.cycleBar(cycle), tint: tint) }
                    if let trial = model.trialNote {
                        Text(verbatim: trial).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.liteSurface, in: RoundedRectangle(cornerRadius: 16))
            }

            let meters = model.meterBars()
            if !meters.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(meters.indices, id: \.self) { index in
                        AriaCreditsBar(content: meters[index].bar,
                                       tint: model.meterTint(isWarning: meters[index].isWarning, tone: summary.tone))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.liteSurface, in: RoundedRectangle(cornerRadius: 16))
            }

            if let history = summary.history, !history.days.isEmpty {
                AriaCreditsChart(history: history, accessibilityText: model.chartDescription(history))
                    .padding(16)
                    .background(Color.liteSurface, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    /// La cifra grande ("27.6") con la sua etichetta ("credits available") e l'eventuale nota sui rinnovi.
    private func big(_ big: AriaAllowanceSummary.Big) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: big.value)
                .font(.largeTitle.weight(.bold))
                .monospacedDigit()
            Text(verbatim: big.label).font(.headline)
            if let note = big.note {
                Text(verbatim: note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// Ambra per l'avviso, grigio per il tetto raggiunto, accento per le informazioni: mai rosso.
    private func alertBox(_ alert: AriaAllowanceSummary.Alert) -> some View {
        let tint = model.tint(alert.severity)
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: alert.severity == .warning ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: alert.title).font(.subheadline.weight(.semibold))
                Text(verbatim: alert.body)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("credits.alert")
    }
}
