//
//  AriaWorkOrderStore.swift
//  AriaLite
//
//  Lavori assegnati all'utente mobile e la sua disponibilità, sull'host dei lavori
//  (GET /v1/mobile/me, PUT /v1/mobile/me/availability, GET /v1/mobile/work-orders[/{id}]).
//
//  • `available` dura 12 ore: si rimanda all'apertura dell'app e a ogni ritorno in primo piano
//    (rimandare lo stesso valore riparte da 12 ore). `busy` / `off_duty` non scadono, non serve.
//  • Niente notifiche push: la lista si ricarica all'apertura, al ritorno e col pull-to-refresh.
//  • 404 sul dettaglio = l'ordine non è più dell'operatore (riassegnato): sparisce dalla lista, senza errori.
//

import Foundation
import Observation

@Observable
final class AriaWorkOrderStore {
    enum Detail {
        case found(AriaWorkOrder)
        /// L'ordine non è più dell'operatore.
        case gone
    }

    private(set) var profile: AriaMobileProfile?
    private(set) var orders: [AriaWorkOrder] = []
    /// Task già chiusi (sezione "Past").
    private(set) var closedOrders: [AriaWorkOrder] = []
    private(set) var isLoadingClosed = false
    private(set) var hasLoadedClosed = false
    private(set) var closedError: String?
    private(set) var isLoading = false
    /// La lista è arrivata almeno una volta (distingue "vuota" da "non ancora caricata").
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    /// Ultimo caricamento della lista riuscito.
    private(set) var lastUpdated: Date?
    private(set) var isUpdatingAvailability = false

    /// Disponibilità scelta dall'operatore: è quella che l'app rimanda quando si apre.
    /// Di default `available`, altrimenti l'operatore non riceverebbe mai ordini.
    private(set) var preferredAvailability: AriaAvailability

    @ObservationIgnored private let backend: AriaBackend
    /// Scarta le risposte di una lista superata (cambio filtro, nuovo refresh).
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var isSyncing = false

    private static let preferenceKey = "aria.availability_preference"

    init(backend: AriaBackend) {
        self.backend = backend
        preferredAvailability = UserDefaults.standard.string(forKey: Self.preferenceKey)
            .flatMap(AriaAvailability.init(rawValue:)) ?? .available
    }

    /// Disponibilità mostrata: quella confermata dal server, finché non è arrivata quella scelta.
    /// Mentre il cambio è in corso si mostra già quello scelto.
    var availability: AriaAvailability {
        isUpdatingAvailability ? preferredAvailability : (profile?.availability ?? preferredAvailability)
    }

    // MARK: Sincronizzazione

    /// Apertura dell'app e ritorno in primo piano: disponibilità, poi la lista.
    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        guard await prepare() else { return }
        await run {
            // Solo `available` scade: gli altri valori restano, basta leggere il profilo.
            if self.preferredAvailability == .available {
                try await self.putAvailability(.available)
            } else {
                self.profile = try await self.backend.api.get("v1/mobile/me", host: .mobile)
            }
        }
        await loadOrders()
        await loadClosedOrders()
    }

    /// Pull-to-refresh.
    func refresh() async {
        guard await prepare() else { return }
        await run { self.profile = try await self.backend.api.get("v1/mobile/me", host: .mobile) }
        await loadOrders()
        await loadClosedOrders()
    }

    /// Task chiusi (completati, verificati, annullati) per la sezione "Past", fino a 200: il massimo di GET /v1/mobile/work-orders.
    func loadClosedOrders() async {
        guard !isLoadingClosed, await prepare() else { return }
        isLoadingClosed = true
        defer { isLoadingClosed = false }
        do {
            let list: AriaWorkOrderList = try await backend.api.get(
                "v1/mobile/work-orders",
                query: [URLQueryItem(name: "status", value: "closed"),
                        URLQueryItem(name: "limit", value: "200")],
                host: .mobile)
            closedOrders = list.orders
            hasLoadedClosed = true
            closedError = nil
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled { return }
            if case .signedOut? = error as? AriaError { backend.handle(error) } else { closedError = error.localizedDescription }
        }
    }

    /// L'operatore cambia disponibilità: si ricorda e si manda subito.
    func setAvailability(_ value: AriaAvailability) async {
        guard value != availability, !isUpdatingAvailability else { return }
        let previous = preferredAvailability
        preferredAvailability = value
        isUpdatingAvailability = true
        defer { isUpdatingAvailability = false }
        guard await prepare() else { return restore(previous) }
        do {
            try await putAvailability(value)
            UserDefaults.standard.set(value.rawValue, forKey: Self.preferenceKey)
            // Cambiata la disponibilità, cambia anche cosa arriva: si ricarica la lista.
            await loadOrders()
        } catch {
            restore(previous)
            handle(error)
        }
    }

    /// Il server non ha accettato il cambio: resta la scelta di prima.
    private func restore(_ previous: AriaAvailability) {
        preferredAvailability = previous
    }

    /// Dettaglio aggiornato. Se l'ordine non è più dell'operatore lo toglie dalla lista.
    func detail(of id: String) async -> Detail? {
        guard await prepare() else { return nil }
        do {
            let order: AriaWorkOrder = try await backend.api.get("v1/mobile/work-orders/\(id)", host: .mobile)
            if let index = orders.firstIndex(where: { $0.id == id }) { orders[index] = order }
            if let index = closedOrders.firstIndex(where: { $0.id == id }) { closedOrders[index] = order }
            return .found(order)
        } catch AriaError.http(let status, _) where status == 404 {
            orders.removeAll { $0.id == id }
            closedOrders.removeAll { $0.id == id }
            return .gone
        } catch {
            handle(error)
            return nil
        }
    }

    /// Da scollegati non resta niente dell'operatore precedente.
    func reset() {
        generation += 1
        profile = nil
        orders = []
        closedOrders = []
        hasLoadedClosed = false
        closedError = nil
        hasLoaded = false
        isLoading = false
        errorMessage = nil
        lastUpdated = nil
    }

    func dismissError() { errorMessage = nil }

    // MARK: Privato

    /// Ogni chiamata /v1/mobile vuole il Company-Id (400 senza): lo dà GET /v1/companies.
    private func prepare() async -> Bool {
        guard backend.isSignedIn else { return false }
        await backend.bootstrapIfNeeded()
        guard backend.isSignedIn else { return false }
        guard backend.activeCompanyId != nil else {
            errorMessage = backend.lastError ?? AriaError.missingCompany.localizedDescription
            return false
        }
        return true
    }

    private func putAvailability(_ value: AriaAvailability) async throws {
        profile = try await backend.api.send("PUT", "v1/mobile/me/availability",
                                             body: AriaAvailabilityBody(availability: value), host: .mobile)
    }

    private func loadOrders() async {
        generation += 1
        let current = generation
        isLoading = true
        defer { if current == generation { isLoading = false } }
        do {
            let list: AriaWorkOrderList = try await backend.api.get(
                "v1/mobile/work-orders",
                query: [URLQueryItem(name: "status", value: "open"),
                        URLQueryItem(name: "limit", value: "50")],
                host: .mobile)
            guard current == generation else { return }
            orders = list.orders
            hasLoaded = true
            lastUpdated = .now
            errorMessage = nil
        } catch {
            guard current == generation else { return }
            handle(error)
        }
    }

    private func run(_ operation: () async throws -> Void) async {
        do { try await operation() } catch { handle(error) }
    }

    private func handle(_ error: any Error) {
        // Il pull-to-refresh o il cambio di schermata annulla la richiesta: non è un errore.
        if error is CancellationError || (error as? URLError)?.code == .cancelled { return }
        if case .signedOut? = error as? AriaError {
            // 401 sul token o 403 "Not a member": sessione finita, l'app torna al login.
            backend.handle(error)
            return
        }
        // Qui si è già dentro: "le credenziali sono a posto" non c'entra, il tunnel è solo spento.
        if case .signInHostOffline? = error as? AriaError {
            errorMessage = String(localized: "The server is offline. Try again later.")
            return
        }
        errorMessage = error.localizedDescription
    }
}
