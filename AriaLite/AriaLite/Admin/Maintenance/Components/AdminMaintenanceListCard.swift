//
//  AdminMaintenanceListCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una scheda con un elenco di testi: i passi del piano (numerati) o i ricambi (a punti).
//

import SwiftUI

struct AdminMaintenanceListCard: View {
    let title: LocalizedStringKey
    let systemImage: String
    let items: [String]
    /// Mostrato quando l'elenco è vuoto.
    let emptyText: String
    let numbered: Bool

    @ScaledMetric(relativeTo: .subheadline) private var markerWidth: CGFloat = 24

    var body: some View {
        AdminCard(title: title, systemImage: systemImage) {
            if items.isEmpty {
                AdminSectionNotice(text: emptyText, systemImage: "list.bullet")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(numbered ? "\(index + 1)." : "•")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(Color.liteAccent)
                                .frame(minWidth: markerWidth, alignment: .trailing)
                            Text(item)
                                .font(.subheadline)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }
}
