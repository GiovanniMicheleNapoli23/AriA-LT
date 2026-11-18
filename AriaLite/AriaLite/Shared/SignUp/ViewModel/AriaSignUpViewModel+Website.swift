//
//  AriaSignUpViewModel+Website.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il sito web aziendale del passo Azienda, come sulla web (handover 18/11/26 §1.3): si apre con il dominio
//  dell'email (se non è un provider di posta) e si controlla subito; poi mezzo secondo dopo l'ultimo tasto. Il
//  formato e i provider si dicono senza rete; il dominio deve avere un indirizzo (A o AAAA, 5 s al massimo), chiesto
//  al DNS del telefono. "Non verificato" (il DNS non ha risposto, o si è offline) non blocca il pulsante, ma la
//  creazione dell'azienda ricontrolla e lascia passare solo un sito verificato. Il sito non si manda al backend.
//

import Foundation

extension AriaSignUpViewModel {
    /// Il pulsante può andare avanti con questo sito.
    var websiteAccepted: Bool { websiteStatus.allowsContinuing }

    /// Il dominio dell'email, la prima volta che si arriva al passo Azienda (come la web).
    func prefillWebsite() {
        guard !websitePrefilled else { return }
        websitePrefilled = true
        let suggested = AriaCompanyWebsite.suggested(email: email)
        guard website.isEmpty, !suggested.isEmpty else { return }
        website = suggested
        scheduleWebsiteCheck(after: .zero)
    }

    /// "Riprova" sotto un sito non verificato.
    func retryWebsiteCheck() {
        scheduleWebsiteCheck(after: .zero)
    }

    /// Il campo è cambiato: un "https://" incollato si toglie, poi si ricontrolla dopo la pausa.
    func websiteEdited(from old: String) {
        let kept = AriaCompanyWebsite.fieldText(website)
        guard kept == website else {
            website = kept
            return
        }
        guard website != old else { return }
        scheduleWebsiteCheck(after: websiteDelay)
    }

    /// Il controllo di quello che c'è ora nel campo. Un errore di formato si mostra solo a pausa finita (non mentre si
    /// scrive); una risposta per un testo ormai cambiato non conta.
    private func scheduleWebsiteCheck(after delay: Duration) {
        websiteCheck?.cancel()
        let text = website
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            websiteStatus = .idle
            return
        }
        let format = AriaCompanyWebsite.checkFormat(text)
        if case .ok = format { websiteStatus = .checking } else { websiteStatus = .idle }
        websiteCheck = Task { [weak self] in
            if delay > .zero { try? await Task.sleep(for: delay) }
            guard !Task.isCancelled, let self else { return }
            let result: AriaWebsiteCheck
            if case .problem = format {
                result = format
            } else {
                result = await self.verifyWebsite(text)
            }
            guard !Task.isCancelled, self.website == text else { return }
            self.websiteStatus = AriaWebsiteStatus(result)
        }
    }

    /// Formato, provider, poi il DNS. Offline non si chiede: "non verificato", non "non esiste".
    private func verifyWebsite(_ text: String) async -> AriaWebsiteCheck {
        if case .problem = AriaCompanyWebsite.checkFormat(text) { return AriaCompanyWebsite.checkFormat(text) }
        guard isOnline() else { return .problem(.unverified) }
        return await AriaCompanyWebsite.verify(text, resolver: websiteResolver)
    }

    /// Alla creazione dell'azienda, come il salvataggio della web: solo un sito verificato passa. Altrimenti il campo
    /// e il messaggio sotto il modulo dicono perché.
    func websiteVerifiedForSaving() async -> Bool {
        websiteCheck?.cancel()
        let text = website
        let result = await verifyWebsite(text)
        guard website == text else { return false }
        websiteStatus = AriaWebsiteStatus(result)
        guard case .problem(let problem) = result else { return true }
        errorMessage = String(localized: problem.message)
        return false
    }
}
