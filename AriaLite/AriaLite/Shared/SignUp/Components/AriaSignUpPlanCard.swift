//
//  AriaSignUpPlanCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 11/11/26.
//
//  Il passo Piano: la demo gratuita (durata, cifre e righe dal listino pubblico), il pulsante che chiude
//  l'iscrizione con la nota legale, e gli altri piani. Il testo lo decide AriaTrialOffer; qui resta il layout.
//

import SwiftUI

struct AriaSignUpPlanCard: View {
    @Bindable var model: AriaSignUpViewModel

    var body: some View {
        let offer = AriaTrialOffer(state: model.priceList, locale: .current)
        VStack(alignment: .leading, spacing: 24) {
            AriaSignUpTrialCard(offer: offer)

            VStack(spacing: 14) {
                LoginPrimaryButton(title: offer.ctaTitle(isSaving: model.isSaving), isEnabled: model.canFinish,
                                   isBusy: model.isSaving) {
                    Task { await model.finish() }
                }
                // Con il giro in corso il pulsante mostra solo lo spinner: il testo resta per VoiceOver.
                .accessibilityLabel(Text(offer.ctaTitle(isSaving: model.isSaving)))

                AriaSignUpTrustNote(prefix: offer.legalPrefix, link: offer.legalLink, url: offer.termsURL)
            }

            AriaSignUpOtherPlans(title: offer.otherPlansTitle, rows: offer.otherPlans)
        }
        .task { await model.loadPriceList() }
    }
}

/// "By continuing, you acknowledge Sinaura · AriaPLT's Privacy Policy", con il nome del documento che è un link.
struct AriaSignUpTrustNote: View {
    let prefix: String
    let link: String
    let url: URL

    init(prefix: String, link: String, url: URL) {
        self.prefix = prefix
        self.link = link
        self.url = url
    }

    /// La stessa nota fuori dalla card del piano (sotto "Continua" del membro), come la web.
    init() {
        let offer = AriaTrialOffer(state: .loading)
        self.init(prefix: offer.legalPrefix, link: offer.legalLink, url: offer.termsURL)
    }

    var body: some View {
        Text(note)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .tint(Color.liteAccent)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var note: AttributedString {
        var text = AttributedString("\(prefix) ")
        var name = AttributedString(link)
        name.link = url
        name.underlineStyle = Text.LineStyle.single
        text.append(name)
        return text
    }
}
