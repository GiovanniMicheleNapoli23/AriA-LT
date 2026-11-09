//
//  AdminReportTrendChartCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'andamento dei completamenti come linea per periodo. Con una sola serie area sfumata e nessuna legenda;
//  con più serie una linea per colore e la legenda.
//

import Charts
import SwiftUI

struct AdminReportTrendChartCard: View {
    let points: [AdminReportTrendPoint]

    @ScaledMetric(relativeTo: .caption) private var chartHeight: CGFloat = 200

    private var hasManySeries: Bool { Set(points.map(\.series)).count > 1 }

    var body: some View {
        AdminCard(title: "Completion trend", systemImage: "chart.line.uptrend.xyaxis") {
            if hasManySeries {
                Chart(points) { point in
                    LineMark(x: .value("Period", point.label), y: .value("Count", point.value))
                        .foregroundStyle(by: .value("Series", point.seriesLabel))
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Period", point.label), y: .value("Count", point.value))
                        .foregroundStyle(by: .value("Series", point.seriesLabel))
                }
                .chartXAxis { periodAxis }
                .frame(height: chartHeight)
            } else {
                Chart(points) { point in
                    AreaMark(x: .value("Period", point.label), y: .value("Count", point.value))
                        .foregroundStyle(Color.liteAccent.opacity(0.15).gradient)
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Period", point.label), y: .value("Count", point.value))
                        .foregroundStyle(Color.liteAccent)
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Period", point.label), y: .value("Count", point.value))
                        .foregroundStyle(Color.liteAccent)
                }
                .chartXAxis { periodAxis }
                .frame(height: chartHeight)
            }
        }
    }

    private var periodAxis: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: 6))
    }
}
