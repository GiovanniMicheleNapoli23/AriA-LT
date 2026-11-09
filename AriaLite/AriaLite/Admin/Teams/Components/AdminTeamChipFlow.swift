//
//  AdminTeamChipFlow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una serie di etichette a capo automatico (specialità dei membri): una griglia adattiva, senza scroll.
//

import SwiftUI

struct AdminTeamChipFlow: View {
    let titles: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 6, alignment: .leading)],
                  alignment: .leading, spacing: 6) {
            ForEach(titles, id: \.self) { title in
                Text(verbatim: title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .frame(maxWidth: .infinity)
                    .background(Color.liteAccent.opacity(0.1), in: Capsule())
            }
        }
    }
}
