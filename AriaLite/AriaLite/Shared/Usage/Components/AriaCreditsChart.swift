//
//  AriaCreditsChart.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il grafico degli ultimi sette giorni (Swift Charts): una barra per giornata UTC, oggi in evidenza, con la linea
//  tratteggiata della quota giornaliera. A VoiceOver arriva come una frase sola con i sette valori.
//

import Charts
import SwiftUI

struct AriaCreditsChart: View {
    let history: AriaAllowanceSummary.History
    /// La frase per VoiceOver con i sette valori.
    let accessibilityText: String

    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 140

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Last 7 days").font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                if !history.isEmpty {
                    Text(verbatim: history.average).font(.footnote).foregroundStyle(.secondary)
                }
            }
            if history.isEmpty {
                Text("No usage in the last 7 days yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                bars
                if history.reference != nil { legend }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bars: some View {
        Chart {
            ForEach(history.days, id: \.day) { day in
                BarMark(x: .value("Day", day.day), y: .value("Credits", day.credits))
                    .foregroundStyle(day.day == history.days.last?.day ? Color.liteAccent : Color.liteAccent.opacity(0.4))
                    .cornerRadius(3)
            }
            if let reference = history.reference {
                RuleMark(y: .value("Daily allowance", reference))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(Color.secondary)
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let id = value.as(String.self), let day = history.days.first(where: { $0.day == id }) {
                        Text(verbatim: day.label).font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) {
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .frame(height: chartHeight)
        // Con testo molto grande le sette etichette dei giorni non ci starebbero.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var legend: some View {
        HStack(spacing: 6) {
            Rectangle()
                .stroke(Color.secondary, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .frame(width: 18, height: 1)
                .accessibilityHidden(true)
            Text("Daily allowance")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
