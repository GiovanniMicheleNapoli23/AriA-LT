//
//  AdminAlarmNumberedList.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Un elenco del dettaglio: passi con il numero in un cerchio tinto, oppure cause con un punto. Ogni voce
//  può avere un dettaglio sotto (i passi della diagnosi).
//

import SwiftUI

struct AdminAlarmNumberedList: View {
    struct Item: Hashable {
        var title: String
        var detail: String?
    }

    let items: [Item]
    var isNumbered = true

    @ScaledMetric(relativeTo: .subheadline) private var markerSide: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 10) {
                    marker(index)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: item.title)
                            .font(.subheadline)
                        if let detail = item.detail {
                            Text(verbatim: detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    // Il testo parte a metà del cerchio, come la prima riga.
                    .padding(.top, isNumbered ? 2 : 0)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    @ViewBuilder
    private func marker(_ index: Int) -> some View {
        if isNumbered {
            Text(verbatim: "\(index + 1)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(Color.liteAccent)
                .frame(width: markerSide, height: markerSide)
                .background(Color.liteAccent.opacity(0.1), in: Circle())
        } else {
            Circle()
                .fill(Color.liteAccent.opacity(0.6))
                .frame(width: markerSide * 0.28, height: markerSide * 0.28)
                .frame(width: markerSide * 0.5, height: markerSide * 0.75)
                .accessibilityHidden(true)
        }
    }
}

extension AdminAlarmNumberedList {
    /// Righe di solo testo (cause tipiche, passi di risoluzione).
    init(lines: [String], isNumbered: Bool = true) {
        self.init(items: lines.map { Item(title: $0) }, isNumbered: isNumbered)
    }
}
