//
//  AdminMemberSeatsLine.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  La riga in cima all'elenco con le licenze dell'app ("App seats: 7 of 10"), in arancio quando sono finite.
//

import SwiftUI

struct AdminMemberSeatsLine: View {
    let text: String
    let isFull: Bool

    var body: some View {
        Label {
            Text(verbatim: text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isFull ? Color.orange : Color.secondary)
        } icon: {
            Image(systemName: isFull ? "exclamationmark.circle" : "iphone")
                .foregroundStyle(isFull ? Color.orange : Color.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .ariaGlass(in: Capsule())
        .accessibilityElement(children: .combine)
    }
}
