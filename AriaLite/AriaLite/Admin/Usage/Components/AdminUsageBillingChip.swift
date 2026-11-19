//
//  AdminUsageBillingChip.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La pillola di stato dei controlli di fatturazione ("In force", "Reached", "Custom", "Owner", "Inactive"): testo corto su
//  uno sfondo tenue dello stesso colore. Normale = accento, avviso = ambra, "over" = grigio (mai rosso per un dato).
//

import SwiftUI

struct AdminUsageBillingChip: View {
    let text: String
    var tone: AdminUsageTone = .normal

    var body: some View {
        Text(verbatim: text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tone.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tone.tint.opacity(0.14), in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
    }
}
