//
//  AdminLLMUsageViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione LLM Usage, come la pagina /settings/usage della web. Vive in AppViewModel: i dati restano fra un
//  cambio di sezione e l'altro. Riepilogo, listino e sessioni si caricano ognuno per conto suo: se uno fallisce
//  gli altri restano a schermo.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminLLMUsageViewModel {
    let backend: AriaBackend

    // MARK: - Periodo

    /// Il periodo del riepilogo: cambiarlo ricarica solo il riepilogo.
    var period: AdminLLMUsagePeriod = .days30 {
        didSet {
            guard period != oldValue else { return }
            summary = nil
            summaryFailure = nil
            Task { await loadSummary() }
        }
    }

    /// Il listino è aperto? Solo la visibilità della sezione, chiusa di default.
    var showsPricing = false

    // MARK: - Stato delle tre sezioni

    private(set) var summary: AdminLLMUsageSummary?
    private(set) var isLoadingSummary = false
    private(set) var summaryFailure: String?

    private(set) var pricing: AdminLLMUsagePricing?
    private(set) var isLoadingPricing = false
    private(set) var pricingFailure: String?

    private(set) var sessions: [AdminLLMUsageSession] = []
    private(set) var isLoadingSessions = false
    private(set) var sessionsFailure: String?

    private(set) var lastUpdated: Date?

    // MARK: - Stop

    /// La sessione da fermare, in attesa di conferma.
    var sessionToStop: AdminLLMUsageSession?
    private(set) var stoppingSessionId: String?
    /// Errore dello Stop (alert).
    var stopFailure: String?

    var isShowingStopConfirmation: Bool {
        get { sessionToStop != nil }
        set { if !newValue { sessionToStop = nil } }
    }

    var isShowingStopFailure: Bool {
        get { stopFailure != nil }
        set { if !newValue { stopFailure = nil } }
    }

    init(backend: AriaBackend) {
        self.backend = backend
    }

    /// All'uscita dall'account: niente consumo né sessioni dell'azienda precedente.
    /// Il periodo scelto non è un dato dell'azienda: resta com'è, senza scatenare una chiamata.
    func reset() {
        summary = nil
        isLoadingSummary = false
        summaryFailure = nil
        pricing = nil
        isLoadingPricing = false
        pricingFailure = nil
        sessions = []
        isLoadingSessions = false
        sessionsFailure = nil
        lastUpdated = nil
        sessionToStop = nil
        stoppingSessionId = nil
        stopFailure = nil
    }

    // MARK: - Caricamento

    /// Cambia quando va riscaricato tutto: azienda diversa.
    var loadKey: String { backend.activeCompanyId ?? "-" }

    /// Carica le tre sezioni in parallelo, ognuna con il proprio errore.
    func loadAll() async {
        async let summaryLoad: Void = loadSummary()
        async let pricingLoad: Void = loadPricing()
        async let sessionsLoad: Void = loadSessions()
        _ = await (summaryLoad, pricingLoad, sessionsLoad)
    }

    /// Pull-to-refresh: come il primo caricamento.
    func refresh() async {
        await loadAll()
    }

    func loadSummary() async {
        let requested = period
        let company = loadKey
        let range = requested.range(endingAt: Date())
        isLoadingSummary = true
        defer { isLoadingSummary = false }
        do {
            let fresh = try await AdminLLMUsageAPI(api: backend.api).summary(from: range.from, to: range.to)
            // Nel frattempo è cambiato periodo o azienda: questa risposta non serve più.
            guard requested == period, company == loadKey else { return }
            summary = fresh
            summaryFailure = nil
            lastUpdated = Date()
        } catch {
            guard requested == period, company == loadKey else { return }
            if let message = AdminLLMUsageFailure.message(for: error, backend: backend) { summaryFailure = message }
        }
    }

    func loadPricing() async {
        let company = loadKey
        isLoadingPricing = true
        defer { isLoadingPricing = false }
        do {
            let fresh = try await AdminLLMUsageAPI(api: backend.api).pricing()
            guard company == loadKey else { return }
            pricing = fresh
            pricingFailure = nil
        } catch {
            guard company == loadKey else { return }
            if let message = AdminLLMUsageFailure.message(for: error, backend: backend) { pricingFailure = message }
        }
    }

    func loadSessions() async {
        let company = loadKey
        isLoadingSessions = true
        defer { isLoadingSessions = false }
        do {
            let fresh = try await AdminLLMUsageAPI(api: backend.api).sessions()
            guard company == loadKey else { return }
            sessions = fresh
            sessionsFailure = nil
        } catch {
            guard company == loadKey else { return }
            if let message = AdminLLMUsageFailure.message(for: error, backend: backend) { sessionsFailure = message }
        }
    }

    /// Ferma la sessione confermata e aggiorna la sua riga in lista.
    func confirmStop() async {
        guard let session = sessionToStop, stoppingSessionId == nil else { return }
        sessionToStop = nil
        stoppingSessionId = session.id
        defer { stoppingSessionId = nil }
        do {
            let updated = try await AdminLLMUsageAPI(api: backend.api).stop(sessionId: session.id)
            if let index = sessions.firstIndex(where: { $0.id == updated.id }) {
                sessions[index] = updated
            }
        } catch {
            // 404: la sessione non c'è più. Si rilegge l'elenco invece di mostrare un errore.
            if case .http(404, _)? = error as? AriaError {
                await loadSessions()
                return
            }
            stopFailure = AdminLLMUsageFailure.message(for: error, backend: backend)
        }
    }
}
