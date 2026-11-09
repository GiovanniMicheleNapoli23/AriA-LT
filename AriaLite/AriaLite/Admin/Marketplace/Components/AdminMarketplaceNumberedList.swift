//
//  AdminMarketplaceNumberedList.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Un elenco numerato (regole, passi di una procedura). Il numero ha una colonna che cresce col Dynamic Type.
//

import SwiftUI

struct AdminMarketplaceNumberedList: View {
    let items: [String]

    @ScaledMetric(relativeTo: .footnote) private var numberWidth: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, text in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: "\(index + 1)")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: numberWidth, alignment: .trailing)
                    Text(verbatim: text)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
