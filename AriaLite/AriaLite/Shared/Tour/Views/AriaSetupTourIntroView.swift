//
//  AriaSetupTourIntroView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  L'intro di "Primi passi con AriA": una scheda modale al centro con l'orb di Aria (fermo, un solo fotogramma:
//  lo shader acceso costerebbe CPU), titolo, testo, le sezioni come chip e un solo pulsante, "Let's start". Niente
//  contatore. Nel replay in alto a destra c'è "Close". Il velo dietro assorbe ogni tocco.
//

import SwiftUI

struct AriaSetupTourIntroView: View {
    let tour: AriaSetupTourViewModel
    @ScaledMetric(relativeTo: .largeTitle) private var orbSide: CGFloat = 84

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {}
                .accessibilityHidden(true)

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
            .accessibilityIdentifier("setupTour.intro")
            .ariaReadableWidth(520)
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
    }

    private var content: some View {
        VStack(spacing: 14) {
            if tour.isClosable {
                HStack {
                    Spacer(minLength: 0)
                    Button("Close") { tour.close() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.liteAccent)
                        .accessibilityIdentifier("setupTour.close")
                }
            }
            AriaOrb(isAnimating: false)
                .frame(width: orbSide, height: orbSide)
            VStack(spacing: 8) {
                Text("Get the most out of AriA")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.liteText)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("A few steps, one section at a time: your documents, your agents, your team and the systems you already use. Each one makes AriA's answers better.")
                    .font(.body)
                    .foregroundStyle(Color.liteText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            AriaSetupTourChips(titles: tour.sections.map(\.title), alignment: .center)
            Button {
                tour.next()
            } label: {
                Text("Let's start")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.liteAccent)
            .foregroundStyle(Color.liteOnAccent)
            .padding(.top, 4)
            .accessibilityIdentifier("setupTour.start")
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }
}
