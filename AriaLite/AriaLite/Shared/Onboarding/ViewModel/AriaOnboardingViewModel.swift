//
//  AriaOnboardingViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  La presentazione dell'app: prima la scelta fra tecnico e admin, poi le pagine di quel ruolo.
//  "Salta" e l'ultima pagina chiudono (`onFinish`); al primo avvio si va al login, dal profilo si torna indietro.
//

import Foundation
import Observation

@MainActor
@Observable
final class AriaOnboardingViewModel {
    /// Come si arriva alla presentazione: cambia solo il pulsante dell'ultima pagina.
    enum Origin {
        /// Primo avvio, prima del login: l'ultima pagina porta all'accesso.
        case firstLaunch
        /// Dal profilo, con l'accesso già aperto.
        case profile
    }

    /// `nil`: la prima schermata, la scelta del ruolo.
    private(set) var audience: AriaOnboardingAudience?
    /// La pagina mostrata: è la selezione del TabView, quindi cambia anche scorrendo.
    var pageIndex = 0

    let audiences = AriaOnboardingAudience.allCases
    private let origin: Origin
    @ObservationIgnored private let onFinish: () -> Void

    init(origin: Origin, onFinish: @escaping () -> Void) {
        self.origin = origin
        self.onFinish = onFinish
    }

    var pages: [AriaOnboardingPage] { audience?.pages ?? [] }

    /// Falso senza pagine: tornando alla scelta, la schermata che esce non cambia pulsante a metà animazione.
    var isLastPage: Bool { !pages.isEmpty && pageIndex >= pages.count - 1 }

    var primaryTitle: LocalizedStringResource {
        guard isLastPage else { return "Continue" }
        switch origin {
        case .firstLaunch: return "Sign in"
        case .profile: return "Done"
        }
    }

    /// Il richiamo sotto l'ultima pagina: dopo, la presentazione non torna da sola.
    var showsReplayHint: Bool { origin == .firstLaunch && isLastPage }

    /// Il simbolo nel medaglione della sfera: quello della pagina, nessuno nella scelta del ruolo.
    var currentSymbol: String? {
        pages.indices.contains(pageIndex) ? pages[pageIndex].symbol : nil
    }

    var pageLabel: String {
        String(localized: "Page \(pageIndex + 1) of \(pages.count)")
    }

    // MARK: Azioni

    func choose(_ audience: AriaOnboardingAudience) {
        pageIndex = 0
        self.audience = audience
    }

    func next() {
        if isLastPage {
            finish()
        } else {
            pageIndex += 1
        }
    }

    /// Una pagina indietro; dalla prima si torna alla scelta del ruolo.
    func back() {
        if pageIndex > 0 {
            pageIndex -= 1
        } else {
            audience = nil
        }
    }

    func finish() {
        onFinish()
    }
}
