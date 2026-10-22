//
//  AdminScenarioReviewRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda di una sessione da rivedere: titolo, codice allarme e data, il verdetto con chi l'ha dato,
//  il voto e se è stata chiusa senza riparazione.
//

import SwiftUI

struct AdminScenarioReviewRow: View {
    let review: AdminScenarioSessionReview

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    if let code = review.alarmCode {
                        Text(code)
                            .font(.caption.weight(.bold).monospaced())
                            .foregroundStyle(Color.liteAccent)
                    }
                    Text(review.displayTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }
                Spacer(minLength: 8)
                if !review.isReviewed {
                    AdminScenarioBadge(text: String(localized: "To review"), tone: .warning, systemImage: "hourglass")
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) { badges }
                VStack(alignment: .leading, spacing: 6) { badges }
            }
            if let line = review.metaLine {
                Text(line)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var badges: some View {
        AdminScenarioBadge(text: review.verdict.map(AdminScenarioLabel.verdict) ?? String(localized: "No verdict"),
                           tone: AdminScenarioLabel.verdictTone(review.verdict))
        if let source = review.verdictSource {
            AdminScenarioBadge(text: AdminScenarioLabel.verdictSource(source),
                               tone: AdminScenarioLabel.isHumanSource(source) ? .info : .neutral,
                               systemImage: AdminScenarioLabel.isHumanSource(source) ? "person.fill" : "sparkles")
        }
        if review.forceClosed == true {
            AdminScenarioBadge(text: String(localized: "Closed without fix"), tone: .negative)
        }
    }
}
