//
//  AriaSetupTourStepCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda di un passo: in testa l'anello di avanzamento con il simbolo, accanto contatore ("2 of 8", intro esclusa)
//  e titolo; poi testo, chip, "Back" (tondo, con la freccia) e "Next · <prossima schermata>" che prende il resto
//  della riga (all'ultimo "Go to the chat"). Se il nome della schermata non sta in una riga va sotto "Next", in
//  piccolo, invece di spezzarsi. La X piccola c'è solo nel replay. È modale per VoiceOver, che legge
//  "contatore · titolo. testo". Scorre se il testo è molto grande.
//

import SwiftUI

struct AriaSetupTourStepCard: View {
    let tour: AriaSetupTourViewModel
    let step: AriaSetupTourStep
    @ScaledMetric(relativeTo: .headline) private var buttonHeight: CGFloat = 50

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
                .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color.liteSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.liteBorder)
        }
        .shadow(color: .black.opacity(0.18), radius: 20, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("setupTour.card")
        .ariaReadableWidth(520)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            message
            if !step.chips.isEmpty { AriaSetupTourChips(titles: step.chips) }
            buttons.padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
    }

    // MARK: Testata

    /// Anello, contatore e titolo su una riga sola: il titolo non perde una riga sotto l'anello.
    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            AriaSetupTourProgressRing(symbol: step.symbol, fraction: tour.progressFraction)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: tour.counterLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(step.title)
                    .font(.headline)
                    .foregroundStyle(Color.liteText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "\(tour.counterLabel) · \(String(localized: step.title)). \(String(localized: currentMessage))"))
            .accessibilityAddTraits(.isHeader)
            if tour.isClosable {
                Button {
                    tour.close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Color.liteBorder, in: Circle())
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(Text("Close"))
                .accessibilityIdentifier("setupTour.close")
            }
        }
    }

    private var currentMessage: LocalizedStringResource { tour.currentMessage ?? step.message() }

    /// Il testo del passo; VoiceOver lo legge già con il titolo.
    private var message: some View {
        Text(currentMessage)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHidden(true)
    }

    // MARK: Pulsanti

    /// "Back" tondo a sinistra, "Next" che prende il resto. Con il testo enorme "Back" va sotto, a tutta larghezza.
    private var buttons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                backButton(compact: true)
                nextButton
            }
            VStack(spacing: 10) {
                nextButton
                backButton(compact: false)
            }
        }
    }

    private func backButton(compact: Bool) -> some View {
        Button {
            tour.back()
        } label: {
            Group {
                if compact {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .frame(width: buttonHeight, height: buttonHeight)
                } else {
                    Text("Back")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: buttonHeight)
                }
            }
            .foregroundStyle(Color.liteText)
            .background(Color.liteBorder, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Back"))
        .accessibilityIdentifier("setupTour.back")
    }

    private var nextButton: some View {
        Button {
            tour.next()
        } label: {
            nextLabel
                .foregroundStyle(Color.liteOnAccent)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: buttonHeight)
                .background(Color.liteAccent, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: nextAccessibilityLabel))
        .accessibilityIdentifier("setupTour.next")
    }

    /// "Next · Teams" su una riga; se non sta, "Next" con il nome della schermata sotto in piccolo; all'ultimo passo
    /// "Go to the chat".
    @ViewBuilder
    private var nextLabel: some View {
        if let next = tour.nextStep {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 5) {
                    Text("Next").font(.headline)
                    Text(verbatim: "·").font(.headline).opacity(0.6)
                    Text(next.screenName).font(.subheadline.weight(.medium)).opacity(0.8)
                }
                .lineLimit(1)
                VStack(spacing: 0) {
                    Text("Next").font(.headline)
                    Text(next.screenName)
                        .font(.caption.weight(.medium))
                        .opacity(0.8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.vertical, 6)
            }
        } else {
            Text("Go to the chat").font(.headline)
        }
    }

    private var nextAccessibilityLabel: String {
        if let next = tour.nextStep {
            return "\(String(localized: "Next")), \(String(localized: next.screenName))"
        }
        return String(localized: "Go to the chat")
    }
}
