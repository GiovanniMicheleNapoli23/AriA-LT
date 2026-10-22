//
//  AdminCraftedSessionRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La riga di una sessione conclusa: titolo, allarme, data e verdetto con la sua fonte.
//

import SwiftUI

struct AdminCraftedSessionRow: View {
    let review: AdminCraftedSessionReview

    @ScaledMetric(relativeTo: .headline) private var iconSize: CGFloat = 34

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: AdminCraftedVerdict.systemImage(review.verdict))
                .font(.headline)
                .foregroundStyle(AdminCraftedVerdict.tint(review.verdict))
                .frame(width: iconSize, height: iconSize)
                .background(AdminCraftedVerdict.tint(review.verdict).opacity(0.12), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(review.displayTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) { details }
                    VStack(alignment: .leading, spacing: 2) { details }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text(AdminCraftedVerdict.label(review.verdict))
                        .fontWeight(.semibold)
                        .foregroundStyle(AdminCraftedVerdict.tint(review.verdict))
                    if let source = AdminCraftedVerdict.sourceLabel(review.verdictSource) {
                        Text(verbatim: "·").foregroundStyle(.tertiary)
                        Text(source).foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var details: some View {
        if let alarm = review.alarmCode, !alarm.isEmpty {
            Label(alarm, systemImage: "bell")
        }
        if let date = review.date {
            Text(date.formatted(date: .abbreviated, time: .shortened))
        }
        if let rating = review.reviewRating {
            Label("\(rating)/5", systemImage: "star")
        }
    }
}
