//
//  AdminUserTeamChip.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Un team di appartenenza come capsula neutra (le specialità hanno la loro, in tinta).
//

import SwiftUI

struct AdminUserTeamChip: View {
    let title: String

    var body: some View {
        Text(verbatim: title)
            .font(.footnote.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(.tertiarySystemFill), in: Capsule())
            .foregroundStyle(.primary)
    }
}
