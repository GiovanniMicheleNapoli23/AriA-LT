//
//  AdminMemberAvatar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il cerchio con le iniziali di un membro. Un membro non attivo è più spento. La misura segue il testo.
//

import SwiftUI

struct AdminMemberAvatar: View {
    let initials: String
    var isActive = true
    var isLarge = false

    @ScaledMetric(relativeTo: .headline) private var regular: CGFloat = 40
    @ScaledMetric(relativeTo: .title) private var large: CGFloat = 64

    var body: some View {
        let side = isLarge ? large : regular
        Text(verbatim: initials)
            .font(isLarge ? .title2.weight(.semibold) : .subheadline.weight(.semibold))
            .foregroundStyle(Color.liteAccent)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .frame(width: side, height: side)
            .background(Color.liteAccent.opacity(isActive ? 0.12 : 0.05), in: Circle())
            .opacity(isActive ? 1 : 0.6)
            .accessibilityHidden(true)
    }
}
