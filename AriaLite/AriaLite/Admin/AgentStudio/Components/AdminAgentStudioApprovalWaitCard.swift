//
//  AdminAgentStudioApprovalWaitCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  La scheda arancione del run fermo su un'approvazione: titolo, rischio, scadenza e il link per decidere.
//

import SwiftUI

struct AdminAgentStudioApprovalWaitCard: View {
    let approval: AdminAgentStudioLiveRun.PendingApproval

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Waiting for your approval", systemImage: "hand.raised.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.orange)
            Text(approval.title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            if let meta = metaLine {
                Text(meta)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            NavigationLink(value: AdminAgentStudioRoute.approval(id: approval.id)) {
                Label("Review approval", systemImage: "arrow.right.circle")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16), tint: Color.orange.opacity(0.2))
        .accessibilityElement(children: .contain)
    }

    private var metaLine: String? {
        var parts: [String] = []
        if let tier = approval.riskTier { parts.append(String(localized: "Risk: \(tier.capitalized)")) }
        if let date = approval.expiresAt {
            parts.append(String(localized: "Expires \(date.formatted(.relative(presentation: .named)))"))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
