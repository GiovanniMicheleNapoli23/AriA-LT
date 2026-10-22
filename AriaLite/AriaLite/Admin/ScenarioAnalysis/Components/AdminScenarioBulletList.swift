//
//  AdminScenarioBulletList.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un elenco puntato di testi (passi completati, cose trovate), numerato se serve.
//

import SwiftUI

struct AdminScenarioBulletList: View {
    let items: [String]
    var numbered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: numbered ? "\(index + 1)." : "•")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Color.liteAccent)
                    Text(item)
                        .font(.subheadline)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
