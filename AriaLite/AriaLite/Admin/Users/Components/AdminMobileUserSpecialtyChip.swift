//
//  AdminMobileUserSpecialtyChip.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una specialità come capsula; con `onRemove` ha anche la "x" per toglierla (nel foglio di modifica).
//

import SwiftUI

struct AdminMobileUserSpecialtyChip: View {
    let title: String
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
            if let onRemove {
                Button("Remove \(title)", systemImage: "xmark.circle.fill", action: onRemove)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.liteAccent.opacity(0.12), in: Capsule())
        .foregroundStyle(Color.liteAccent)
    }
}
