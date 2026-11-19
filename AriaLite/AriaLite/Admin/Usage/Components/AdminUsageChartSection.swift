//
//  AdminUsageChartSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda del grafico dei crediti (contratto 3.6): una barra per giorno UTC, la parte oltre gli inclusi in grigio, i
//  giorni proiettati più chiari, le linee degli inclusi e dell'avviso e, a dimensione, la linea "Credits per action".
//  Per VoiceOver è un'immagine sola con la frase del modello.
//

import Charts
import SwiftUI

struct AdminUsageChartSection: View {
    let chart: AdminUsageChart

    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 200

    var body: some View {
        AdminUsageCardFrame(title: Text(verbatim: chart.title), description: Text(verbatim: chart.description)) {
            if chart.isEmpty {
                Text(verbatim: chart.emptyText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                bars
                AdminUsageChartLegend(chart: chart)
            }
        }
    }

    private var bars: some View {
        Chart {
            ForEach(chart.drawnPoints) { point in
                AdminUsageChartBars(point: point)
            }
            if chart.bySize {
                ForEach(chart.drawnPoints) { point in
                    AdminUsageChartLine(point: point)
                }
            }
            AdminUsageChartReferences(chart: chart)
        }
        .chartXScale(domain: chart.days)
        .chartXAxis {
            AxisMarks(values: chart.axisDays) { value in
                AxisValueLabel {
                    if let day = value.as(String.self), let label = chart.axisLabel(for: day) {
                        Text(verbatim: label).font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(number, format: .number.notation(.compactName)).font(.caption2)
                    }
                }
            }
        }
        .frame(height: chartHeight)
        // Con testo molto grande le etichette dell'asse non ci starebbero.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(chart.accessibilityLabel)
    }
}

/// Le barre di un giorno: la parte fino agli inclusi e, sopra, quella oltre (grigia). Più chiare se proiettate.
struct AdminUsageChartBars: ChartContent {
    let point: AdminUsageChartPoint

    private var isProjected: Bool { point.kind == .projected }
    private var baseColor: Color { isProjected ? Color.liteAccent.opacity(0.3) : Color.liteAccent }
    private var overColor: Color { isProjected ? Color.secondary.opacity(0.35) : Color.secondary }

    var body: some ChartContent {
        BarMark(
            x: .value("Day", point.day),
            yStart: .value("From", 0.0),
            yEnd: .value("Up to included", point.base),
            width: .ratio(0.7))
            .foregroundStyle(baseColor)
        if point.over > 0 {
            BarMark(
                x: .value("Day", point.day),
                yStart: .value("Included", point.base),
                yEnd: .value("Total", point.base + point.over),
                width: .ratio(0.7))
                .foregroundStyle(overColor)
        }
    }
}

/// Il totale corrente dei crediti addebitati per azione, quando il ciclo è contato a dimensione.
struct AdminUsageChartLine: ChartContent {
    let point: AdminUsageChartPoint

    var body: some ChartContent {
        if let charged = point.charged {
            LineMark(x: .value("Day", point.day), y: .value("Credits per action", charged))
                .foregroundStyle(Color.primary.opacity(0.75))
                .lineStyle(StrokeStyle(lineWidth: 2))
        }
    }
}

/// Le linee di riferimento: gli inclusi (tratteggiata, grigia) e la soglia dell'avviso (ambra), ognuna con il suo testo.
struct AdminUsageChartReferences: ChartContent {
    let chart: AdminUsageChart

    var body: some ChartContent {
        if let included = chart.included {
            RuleMark(y: .value("Included", included))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(Color.secondary)
                .annotation(position: .top, alignment: .leading, spacing: 2, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                    if let label = chart.includedLabel {
                        Text(verbatim: label).font(.caption2).foregroundStyle(.secondary)
                    }
                }
        }
        if let notice = chart.notice {
            RuleMark(y: .value("Notice", notice))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                .foregroundStyle(Color.liteWarning)
                .annotation(position: .bottom, alignment: .leading, spacing: 2, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                    if let label = chart.noticeLabel {
                        Text(verbatim: label).font(.caption2).foregroundStyle(Color.liteWarning)
                    }
                }
        }
    }
}

/// La legenda: usati, extra, proiezione e, a dimensione, i crediti per azione. Va a capo da sola.
struct AdminUsageChartLegend: View {
    let chart: AdminUsageChart

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12, alignment: .leading)], alignment: .leading, spacing: 6) {
            item(Color.liteAccent, chart.usedLegend, isLine: false)
            if let text = chart.perActionLegend { item(Color.primary.opacity(0.75), text, isLine: true) }
            if let text = chart.extraLegend { item(Color.secondary, text, isLine: false) }
            if let text = chart.projectionLegend { item(Color.liteAccent.opacity(0.3), text, isLine: false) }
        }
        .accessibilityHidden(true)
    }

    private func item(_ color: Color, _ text: String, isLine: Bool) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: isLine ? 3 : 12)
            Text(verbatim: text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
