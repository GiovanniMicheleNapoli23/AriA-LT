//
//  AdminCompanySettingsViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Settings, come la pagina /settings della web: l'azienda attiva, i suoi stabilimenti e la
//  "Danger zone" per cancellarne i dati. Vive in AppViewModel: i dati restano fra un cambio di sezione e l'altro.
//  Azienda e stabilimenti vengono da `backend` (già caricati): qui non si chiamano le rotte di elenco.
//  Azioni e conferma in +Actions.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminCompanySettingsViewModel {
    let backend: AriaBackend

    /// Stato dello sheet di conferma.
    enum Phase: Equatable {
        case confirming
        case running
        case succeeded
        case failed(String)
    }

    /// Cosa si sta per cancellare; `nil` = nessuno sheet aperto.
    var target: AdminCompanySettingsTarget?
    /// Il nome riscritto nel campo di conferma.
    var typedName = ""
    var phase: Phase = .confirming

    init(backend: AriaBackend) {
        self.backend = backend
    }

    /// All'uscita dall'account: nessuno sheet e nessun testo dell'azienda precedente.
    func reset() {
        target = nil
        typedName = ""
        phase = .confirming
    }

    // MARK: Azienda e stabilimenti

    var hasCompany: Bool { backend.activeCompanyId != nil }

    /// Il nome dell'azienda attiva, dall'elenco già scaricato all'accesso.
    var companyName: String? {
        guard let id = backend.activeCompanyId else { return nil }
        return backend.companies.first { $0.id == id }?.name
    }

    var plants: [AriaPlant] { backend.plants }

    var plantCount: Int { plants.count }

    /// Per cancellare i dati dell'azienda serve sapere come si chiama (è quello che si riscrive).
    var canDeleteCompany: Bool { companyName != nil }

    var canDeletePlant: Bool { hasCompany && !plants.isEmpty }

    // MARK: Sheet di conferma

    var isRunning: Bool { phase == .running }

    var isSucceeded: Bool { phase == .succeeded }

    /// Il pulsante rosso si abilita solo con il nome esatto e fuori da un'operazione in corso o finita.
    var canConfirm: Bool {
        guard let target, target.matches(typedName) else { return false }
        return phase != .running && phase != .succeeded
    }
}
