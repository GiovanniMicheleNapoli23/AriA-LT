//
//  AdminTaskboardColumnHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/10/26.
//
//  L'intestazione di una colonna della bacheca: icona e nome dello stato, conteggio nel suo colore.
//

import SwiftUI

struct AdminTaskboardColumnHeader: View {
    let status: AdminWorkOrderStatus
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: status.systemImage).foregroundStyle(status.tint)
            Text(status.localized).font(.headline).lineLimit(1)
            Text(count, format: .number)
                .font(.footnote.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(status.tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(status.tint.opacity(0.14), in: Capsule())
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
