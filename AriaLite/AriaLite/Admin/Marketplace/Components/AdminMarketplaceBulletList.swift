//
//  AdminMarketplaceBulletList.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Un elenco puntato (cause tipiche di un allarme).
//

import SwiftUI

struct AdminMarketplaceBulletList: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, text in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: "•").foregroundStyle(.secondary).accessibilityHidden(true)
                    Text(verbatim: text)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
