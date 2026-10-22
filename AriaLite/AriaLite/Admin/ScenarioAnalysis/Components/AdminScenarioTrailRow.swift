//
//  AdminScenarioTrailRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una voce della traccia di una procedura: cosa è stato detto, da chi e quando, e se ha insegnato qualcosa ad Aria.
//

import SwiftUI

struct AdminScenarioTrailRow: View {
    let event: AdminScenarioFeedbackEvent

    @ScaledMetric(relativeTo: .subheadline) private var iconWidth: CGFloat = 22

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: event.systemImage)
                .foregroundStyle(Color.liteAccent)
                .frame(width: iconWidth)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(event.headline)
                        .font(.subheadline.weight(.semibold))
                    if let stars = AdminScenarioFormat.stars(event.rating) {
                        Text(stars).font(.caption).foregroundStyle(.orange)
                    }
                }
                if let text = event.bodyText {
                    Text(text)
                        .font(.subheadline)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if event.taughtAria {
                    Label("Aria learned from this", systemImage: "lightbulb")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
                if let footnote = event.footnote {
                    Text(footnote).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}
