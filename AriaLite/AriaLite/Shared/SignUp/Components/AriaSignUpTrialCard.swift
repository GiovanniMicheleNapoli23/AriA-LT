//
//  AriaSignUpTrialCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La card della demo gratuita: nome e badge, durata e "No card required", prezzo, le tre cifre e le righe incluse.
//  Tutto il testo viene da AriaTrialOffer; mentre il listino arriva le cifre sono barre grigie.
//

import SwiftUI

struct AriaSignUpTrialCard: View {
    let offer: AriaTrialOffer

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            if offer.isLoading {
                AriaSignUpTrialFiguresPlaceholder()
            } else if !offer.figures.isEmpty {
                AriaSignUpTrialFigures(figures: offer.figures)
            }
            included
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaSignUpCard()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    title
                    badge
                }
                VStack(alignment: .leading, spacing: 8) {
                    title
                    badge
                }
            }
            Text(offer.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            price
        }
    }

    private var title: some View {
        Text(offer.name)
            .font(.title2.weight(.semibold))
            .foregroundStyle(Color.liteText)
            .accessibilityAddTraits(.isHeader)
    }

    private var badge: some View {
        Text(offer.badge)
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.liteAccent)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.liteAccent.opacity(0.12), in: Capsule())
    }

    @ViewBuilder
    private var price: some View {
        if offer.isLoading {
            AriaSignUpPlaceholderBar(width: 80, height: 28)
        } else if let price = offer.price {
            VStack(alignment: .leading, spacing: 2) {
                Text(price)
                    .font(.title.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.liteText)
                if let unit = offer.priceUnit {
                    Text(unit)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var included: some View {
        if offer.runsOn != nil || !offer.lines.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                if let runsOn = offer.runsOn {
                    Text(runsOn)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.liteText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(offer.lines, id: \.self) { line in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Color.liteAccent)
                            .accessibilityHidden(true)
                        Text(line)
                            .font(.subheadline)
                            .foregroundStyle(Color.liteText.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
