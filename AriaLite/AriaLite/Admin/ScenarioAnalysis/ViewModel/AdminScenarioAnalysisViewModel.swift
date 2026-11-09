//
//  AdminScenarioAnalysisViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Scenario analysis, come la pagina /settings/scenario-analysis della web.
//  Vive in AppViewModel: i dati restano fra un cambio di sezione e l'altro.
//  Tiene la scheda scelta e i quattro pezzi della pagina: scenari, revisioni, chiusure e backfill.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminScenarioAnalysisViewModel {
    let backend: AriaBackend
    let scenarios: AdminScenarioListViewModel
    let reviews: AdminScenarioReviewsViewModel
    let closures: AdminScenarioClosuresViewModel
    let backfill: AdminScenarioBackfillViewModel

    var tab: AdminScenarioTab = .scenarios

    init(backend: AriaBackend) {
        self.backend = backend
        let scenarios = AdminScenarioListViewModel(backend: backend)
        let reviews = AdminScenarioReviewsViewModel(backend: backend)
        self.scenarios = scenarios
        self.reviews = reviews
        closures = AdminScenarioClosuresViewModel(backend: backend)
        backfill = AdminScenarioBackfillViewModel(backend: backend)
        // Dopo un backfill gli scenari e i verdetti sono cambiati.
        backfill.onFinished = { [weak scenarios, weak reviews] in
            await scenarios?.load()
            await reviews?.load()
        }
    }

    /// La ricerca della scheda a schermo.
    var searchText: String {
        get {
            switch tab {
            case .scenarios: scenarios.searchText
            case .reviews: reviews.searchText
            case .closures: closures.searchText
            }
        }
        set {
            switch tab {
            case .scenarios: scenarios.searchText = newValue
            case .reviews: reviews.searchText = newValue
            case .closures: closures.searchText = newValue
            }
        }
    }

    var searchPrompt: String {
        switch tab {
        case .scenarios: String(localized: "Title, alarm code, summary")
        case .reviews: String(localized: "Session, alarm code, verdict")
        case .closures: String(localized: "Procedure, alarm, operator")
        }
    }

    /// All'uscita dall'account: non resta niente dell'azienda precedente.
    func reset() {
        tab = .scenarios
        backfill.reset()
        scenarios.reset()
        reviews.reset()
        closures.reset()
    }
}
