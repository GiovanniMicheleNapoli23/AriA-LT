//
//  AdminReportBarChartCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una ripartizione come barre orizzontali con il numero a fianco, dentro una scheda. L'altezza segue il
//  Dynamic Type: le etichette dell'asse restano leggibili.
//

import Charts
import SwiftUI

struct AdminReportBarChartCard: View {
    let title: LocalizedStringKey
    let systemImage: String
    let items: [AdminReportBreakdownItem]

    @ScaledMetric(relativeTo: .caption) private var rowHeight: CGFloat = 32

    /// Le prime dieci: oltre, il grafico diventa illeggibile su un telefono.
    private var shown: [AdminReportBreakdownItem] { Array(items.prefix(10)) }

    var body: some View {
        AdminCard(title: title, systemImage: systemImage) {
            Chart(shown) { item in
                BarMark(x: .value("Count", item.count), y: .value("Category", item.label))
                    .foregroundStyle(Color.liteAccent.gradient)
                    .cornerRadius(4)
                    .annotation(position: .trailing, spacing: 4) {
                        Text(AdminReportFormat.count(item.count))
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
            }
            .chartXAxis(.hidden)
            .frame(height: rowHeight * CGFloat(shown.count) + rowHeight / 2)
        }
    }
}
