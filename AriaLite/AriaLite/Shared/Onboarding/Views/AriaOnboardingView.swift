//
//  AriaOnboardingView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  La presentazione dell'app sullo sfondo del login (chiaro o scuro come il telefono), con la sfera di Aria
//  in alto a sinistra, sulla colonna del testo, che resta ferma per tutta la presentazione. Titoli grandi e leggeri
//  (AriaOnboardingTitle). Prima la scelta fra tecnico e admin su pannelli di vetro, poi le pagine di quel ruolo
//  da scorrere: in alto i segmenti e "Salta",
//  in basso indietro e "Continua". Una sola entrata orchestrata (sfera, testo, scelte); con Riduci movimento appare.
//  Al primo avvio la mostra ContentView prima del login; dal profilo, SettingsSheet a schermo intero.
//  La logica è in AriaOnboardingViewModel; qui restano layout e animazioni.
//

import SwiftUI

struct AriaOnboardingView: View {
    @State private var model: AriaOnboardingViewModel
    @State private var orbIn = false
    @State private var textIn = false
    @State private var choicesIn = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var backSide: CGFloat = 54

    init(origin: AriaOnboardingViewModel.Origin, onFinish: @escaping () -> Void) {
        _model = State(initialValue: AriaOnboardingViewModel(origin: origin, onFinish: onFinish))
    }

    /// iPhone in orizzontale: sfera piccola, così il testo ci sta.
    private var isCompactHeight: Bool { verticalSizeClass == .compact }

    /// La sfera è decorativa: grande nella scelta, un po' meno sulle pagine, piccola dove serve spazio al testo.
    private var orbSide: CGFloat {
        if isCompactHeight { return 56 }
        if dynamicTypeSize.isAccessibilitySize { return 84 }
        return model.audience == nil ? 148 : 116
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.top, 8)

            HStack {
                AriaOnboardingOrb(side: orbSide, symbol: model.currentSymbol)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
            .padding(.top, isCompactHeight ? 4 : 20)
            .padding(.bottom, isCompactHeight ? 8 : 28)
            .ariaReadableWidth(560)
            .scaleEffect(orbIn || reduceMotion ? 1 : 0.7, anchor: .bottomLeading)
            .offset(y: orbIn || reduceMotion ? 0 : 60)
            .opacity(orbIn ? 1 : 0)

            ZStack {
                if let audience = model.audience {
                    pages(audience.pages)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    audiencePicker
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)

            if model.audience != nil {
                bottomBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background { LoginBackdrop() }
        .animation(.snappy, value: model.audience)
        .sensoryFeedback(.selection, trigger: model.pageIndex)
        .onAppear(perform: enter)
    }

    private func enter() {
        guard !orbIn else { return }
        if reduceMotion {
            orbIn = true; textIn = true; choicesIn = true
            return
        }
        withAnimation(.spring(duration: 1.1, bounce: 0.25)) { orbIn = true }
        withAnimation(.spring(duration: 0.8, bounce: 0.1).delay(0.45)) { textIn = true }
        withAnimation(.spring(duration: 0.8, bounce: 0.1).delay(0.7)) { choicesIn = true }
    }

    // MARK: Barra in alto

    private var topBar: some View {
        HStack(spacing: 16) {
            if model.audience != nil {
                AriaOnboardingProgressBar(count: model.pages.count, index: model.pageIndex, label: model.pageLabel)
                    .transition(.opacity)
            } else {
                Spacer()
            }
            Button("Skip", action: model.finish)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.liteAccent)
                .frame(minHeight: 44)
                .buttonStyle(.plain)
                .accessibilityIdentifier("onboarding.skip")
        }
        .padding(.horizontal, 28)
        .ariaReadableWidth(560)
        .opacity(textIn ? 1 : 0)
    }

    // MARK: Scelta del ruolo

    private var audiencePicker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: isCompactHeight ? 18 : 32) {
                VStack(alignment: .leading, spacing: 12) {
                    AriaOnboardingTitle(text: "Welcome to AriaPLT Mobile", size: 48)
                    Text("Who are you? We'll show you what you can do with the app.")
                        .font(.body)
                        .lineSpacing(3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(textIn ? 1 : 0)
                .offset(y: textIn || reduceMotion ? 0 : 14)

                VStack(spacing: 12) {
                    ForEach(model.audiences) { audience in
                        AriaOnboardingAudienceCard(audience: audience) { model.choose(audience) }
                    }
                }
                .opacity(choicesIn ? 1 : 0)
                .offset(y: choicesIn || reduceMotion ? 0 : 28)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
            .ariaReadableWidth(560)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
    }

    // MARK: Pagine

    /// Le pagine arrivano come valore: tornando alla scelta, la schermata che esce resta piena finché scorre via.
    private func pages(_ pages: [AriaOnboardingPage]) -> some View {
        TabView(selection: $model.pageIndex) {
            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                AriaOnboardingPageView(page: page)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    // MARK: Barra in basso

    private var bottomBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    withAnimation(.snappy) { model.back() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .foregroundStyle(Color.liteAccent)
                        .frame(width: backSide, height: backSide)
                        .ariaGlass(in: Circle(), interactive: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Back"))
                .accessibilityIdentifier("onboarding.back")

                LoginPrimaryButton(title: model.primaryTitle, isEnabled: true, isBusy: false) {
                    withAnimation(.snappy) { model.next() }
                }
                .accessibilityIdentifier("onboarding.next")
            }

            if model.showsReplayHint {
                Text("You can see this tour again from your profile.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, isCompactHeight ? 4 : 12)
        .ariaReadableWidth(560)
        .animation(.snappy, value: model.showsReplayHint)
    }
}

#Preview {
    AriaOnboardingView(origin: .firstLaunch) {}
}
