//
//  AdminUsageViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La pagina Usage (contratto, sezioni 2-4 e 6-8): il cruscotto del ciclo corrente (tenuto anche mentre se ne guarda
//  uno passato, perché ha l'elenco `cycles`), quello del ciclo scelto, i membri del titolare e i modelli già scritti
//  che le viste disegnano. Config e saldo hanno UNA copia: `backend.usage`. Le risposte che arrivano dopo un cambio di
//  azienda, di ciclo o un'uscita dall'account non scrivono.
//

import Foundation
import Observation

/// Cosa mostra la pagina (contratto 4).
nonisolated enum AdminUsagePageState: Sendable, Equatable {
    /// La config si sta leggendo: un segnaposto per tutta la pagina.
    case loadingConfig
    /// Il cruscotto si sta leggendo: intestazione e selettore restano, le schede sono segnaposto.
    case loading
    /// Fallita, `enabled: false` o senza `period` (anche un 503): "Usage figures are unavailable right now", Riprova e,
    /// su un ciclo passato, "Back to the current cycle". Mai cifre tenute.
    case unavailable
    case ready
}

@MainActor
@Observable
final class AdminUsageViewModel {
    let backend: AriaBackend
    let locale: Locale

    // MARK: Stato (lo scrivono solo il view model e le sue estensioni)

    /// Il cruscotto del ciclo CORRENTE: ha l'elenco dei cicli. `nil` finché non si legge e dopo un errore (niente cifre).
    var currentDashboard: AriaUsageDashboard?
    var currentPhase: AdminUsagePhase = .idle
    /// Il ciclo corrente e l'elenco del selettore, tenuti anche dopo un errore: il selettore e "Back" restano.
    var currentCycle: AriaUsageDashboard.Cycle?
    var cycles: [AriaUsageDashboard.Cycle] = []
    /// Il ciclo passato scelto; `nil` = il corrente.
    private(set) var selectedCycle: AriaUsageDashboard.Cycle?
    var pastDashboard: AriaUsageDashboard?
    var pastPhase: AdminUsagePhase = .idle

    /// I membri attivi (solo un titolare li legge): danno un nome agli id di `by_user` e dello storico del tetto.
    var members: [AriaNoticeRecipients.Member] = []
    var membersPhase: AdminUsagePhase = .idle

    /// 403 `operation_forbidden`: la sessione non può usare la sezione. La shell la chiude.
    var sectionClosed = false
    /// Una chiamata da titolare è stata rifiutata: le parti da titolare si nascondono finché la config non dice altro.
    var ownerRefused = false
    /// Cresce a ogni uscita dall'account: una risposta partita prima non scrive più.
    var epoch = 0
    /// L'azienda a cui appartiene quello che si tiene: cambiata, si butta tutto (cifre, nomi, ciclo scelto).
    @ObservationIgnored private var heldCompany: String?

    init(backend: AriaBackend, locale: Locale = .autoupdatingCurrent) {
        self.backend = backend
        self.locale = locale
    }

    /// All'uscita dall'account: niente cifre né nomi dell'azienda precedente.
    func reset() {
        epoch += 1
        currentDashboard = nil
        currentPhase = .idle
        currentCycle = nil
        cycles = []
        selectedCycle = nil
        pastDashboard = nil
        pastPhase = .idle
        members = []
        membersPhase = .idle
        sectionClosed = false
        ownerRefused = false
    }

    /// Cambia quando va riletto tutto: azienda diversa (per `.task(id:)`).
    var loadKey: String { backend.activeCompanyId ?? "-" }

    /// Prima di ogni lettura: se l'azienda attiva non è quella delle cifre tenute, si riparte da zero (come all'uscita).
    func claimCompany() {
        let key = loadKey
        if let heldCompany, heldCompany != key { reset() }
        heldCompany = key
    }

    /// La risposta partita con questa epoca e azienda vale ancora.
    func isCurrent(epoch: Int, company: String) -> Bool {
        epoch == self.epoch && company == loadKey
    }

    // MARK: Segnali per la shell

    /// La sezione è chiusa per questa sessione (403 `operation_forbidden`) o il backend non ha le rotte.
    var isClosed: Bool { sectionClosed || backend.usage.isUnavailable }

    /// Un titolare: `config.can_manage_plan`, mai `access.admin` (regola 6). Falso dopo un rifiuto da titolare.
    var isOwner: Bool { backend.usage.config?.canManagePlan == true && !ownerRefused }

    /// I clienti possono vedere i consumi (`billing.customer_visibility`).
    var customersMaySee: Bool { backend.usage.config?.customerVisibility == true }

    // MARK: Ciclo scelto

    var isOnPastCycle: Bool { selectedCycle != nil }

    /// L'inizio del ciclo scelto nel selettore: quello passato, altrimenti il corrente.
    var selectedCycleStart: String? { selectedCycle?.start ?? currentCycle?.start }

    /// Sceglie un ciclo del selettore. Il corrente torna al cruscotto tenuto; un altro lo legge.
    func selectCycle(_ cycle: AriaUsageDashboard.Cycle) async {
        if cycle.start == currentCycle?.start {
            backToCurrentCycle()
            return
        }
        selectedCycle = cycle
        pastDashboard = nil
        pastPhase = .loading
        await loadSelected()
    }

    /// "Back to the current cycle": il cruscotto corrente è già in mano.
    func backToCurrentCycle() {
        selectedCycle = nil
        pastDashboard = nil
        pastPhase = .idle
    }

    // MARK: Cosa mostra la pagina

    /// Il cruscotto che si vede: il corrente, o quello del ciclo passato scelto.
    var shownDashboard: AriaUsageDashboard? {
        // Le cifre di un'altra azienda non si mostrano nemmeno per un attimo, prima che la lettura nuova parta.
        guard heldCompany == nil || heldCompany == loadKey else { return nil }
        return isOnPastCycle ? pastDashboard : currentDashboard
    }

    var shownPhase: AdminUsagePhase { isOnPastCycle ? pastPhase : currentPhase }

    var pageState: AdminUsagePageState {
        let store = backend.usage
        let phase = store.configPhase
        if store.config == nil, phase == .idle || phase == .loading { return .loadingConfig }
        if phase == .failed { return .unavailable }
        guard store.config?.customerVisibility == true else { return .unavailable }
        switch shownPhase {
        case .idle, .loading: return .loading
        case .failed: return .unavailable
        case .loaded: return facts == nil ? .unavailable : .ready
        }
    }

    /// I fatti del cruscotto che si vede; `nil` se non si può disegnare (non letto, `enabled: false`, senza `period`).
    var facts: AdminUsageFacts? {
        guard let dashboard = shownDashboard, var config = backend.usage.config else { return nil }
        // Un rifiuto da titolare nasconde subito le parti da titolare, prima che la config riletta lo confermi.
        if ownerRefused { config.canManagePlan = false }
        return AdminUsageFacts(dashboard: dashboard, config: config, allowance: backend.usage.allowance, locale: locale)
    }

    /// Il saldo si sta leggendo / è fallito, per Today e This week, l'archivio, Live Talk e la scheda del tetto.
    var allowancePhase: AdminUsagePhase { Self.phase(backend.usage.allowancePhase) }

    static func phase(_ phase: AriaUsageStore.Phase) -> AdminUsagePhase {
        switch phase {
        case .idle: .idle
        case .loading: .loading
        case .loaded: .loaded
        case .failed: .failed
        }
    }
}
