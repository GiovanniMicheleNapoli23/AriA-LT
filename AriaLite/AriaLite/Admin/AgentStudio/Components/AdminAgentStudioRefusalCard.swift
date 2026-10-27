//
//  AdminAgentStudioRefusalCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  La scheda rossa del run rifiutato dalla policy, con i motivi uno per riga.
//

import SwiftUI

struct AdminAgentStudioRefusalCard: View {
    let reasons: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("The policy refused this run", systemImage: "xmark.octagon.fill")
                .font(.headline)
                .foregroundStyle(.red)
            ForEach(reasons, id: \.self) { reason in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: "•")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.red)
                        .accessibilityHidden(true)
                    Text(reason)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16), tint: Color.red.opacity(0.18))
        .accessibilityElement(children: .contain)
    }
}
