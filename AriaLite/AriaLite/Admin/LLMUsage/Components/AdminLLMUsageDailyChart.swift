//
//  AdminLLMUsageDailyChart.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il costo giorno per giorno del periodo, un istogramma nel colore dell'app come i grafici della chat.
//

import Charts
import SwiftUI

struct AdminLLMUsageDailyChart: View {
    let days: [AdminLLMUsageChartDay]

    var body: some View {
        Chart(days) { day in
            BarMark(
                x: .value("Day", day.date, unit: .day),
                y: .value("Cost", day.costEur)
            )
            .foregroundStyle(Color.liteAccent.gradient)
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 200)
        .accessibilityLabel(Text("Daily cost"))
    }
}
