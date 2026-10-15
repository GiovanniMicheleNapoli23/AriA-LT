//
//  AriaWorkOrderStore.swift
//  AriaLite
//
//  Created by Giovanni Michele on 08/10/26.
//
//  Lavori assegnati all'operatore mobile e la sua disponibilità, sull'host dei lavori
//  (GET /v1/mobile/me, PUT /v1/mobile/me/availability, GET /v1/mobile/work-orders[/{id}]),
//  più i risultati dei passi, le foto e il completamento (AriaWorkOrderAPI).
//
//  • `available` dura 12 ore: si rimanda all'apertura dell'app e a ogni ritorno in primo piano
//    (rimandare lo stesso valore riparte da 12 ore). `busy` / `off_duty` non scadono, non serve.
//  • Niente notifiche push: la lista si ricarica all'apertura, al ritorno e col pull-to-refresh.
//  • 404 sul dettaglio = l'ordine non è più dell'operatore (riassegnato): sparisce dalla lista, senza errori.
//  • Dopo ogni modifica a un passo si ricarica l'ordine: i passi li può cambiare anche un planner e le
//    foto hanno un URL che scade dopo 10 minuti.
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
                self.profile = try await self.backend.api.get("v1/mobile/me")
            }
        }
        await loadOrders()
        await loadClosedOrders()
    }

    /// Pull-to-refresh.
    func refresh() async {
        guard await prepare() else { return }
        await run { self.profile = try await self.backend.api.get("v1/mobile/me") }
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
                        URLQueryItem(name: "limit", value: "200")])
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
            let order = try await backend.api.workOrder(id: id)
            replace(order)
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

    // MARK: Passi, foto, completamento

    /// Esito di una modifica: l'ordine ricaricato, oppure l'ordine non è più dell'operatore,
    /// oppure il messaggio dell'errore (la modifica non è stata fatta).
    enum Change {
        case updated(AriaWorkOrder)
        case gone
        case failed(String)
    }

    /// Mette (o cambia) il risultato di un passo. Rimandarlo è innocuo, quindi dopo una caduta di rete si può riprovare.
    func report(_ result: AriaStepResult, step stepId: String, of orderId: String) async -> Change {
        await change(orderId, step: stepId) { _ = try await $0.report(result, step: stepId, of: orderId) }
    }

    /// Annulla il risultato di un passo (e le sue foto).
    func clearReport(step stepId: String, of orderId: String) async -> Change {
        await change(orderId, step: stepId) { try await $0.clearReport(step: stepId, of: orderId) }
    }

    /// Aggiunge una foto (JPEG) a un passo che ha già un risultato.
    func addPhoto(jpeg: Data, step stepId: String, of orderId: String) async -> Change {
        await change(orderId, step: stepId) { _ = try await $0.addPhoto(jpeg: jpeg, step: stepId, of: orderId) }
    }

    func removePhoto(_ photoId: String, step stepId: String, of orderId: String) async -> Change {
        await change(orderId, step: stepId) { _ = try await $0.removePhoto(photoId, step: stepId, of: orderId) }
    }

    /// Chiude l'ordine. Con `steps_incomplete` l'errore elenca gli id dei passi senza risultato (`AriaError.workOrder`).
    func complete(_ orderId: String, resolutionNotes: String) async -> Change {
        guard await prepare() else { return .failed(errorMessage ?? AriaError.signedOut.localizedDescription) }
        do {
            let order = try await backend.api.complete(order: orderId, resolutionNotes: resolutionNotes)
            // L'ordine passa dalla lista degli aperti a quella dei chiusi.
            orders.removeAll { $0.id == orderId }
            closedOrders.insert(order, at: 0)
            return .updated(order)
        } catch {
            return await failure(error, orderId: orderId)
        }
    }

    private func change(_ orderId: String, step stepId: String,
                        _ operation: (AriaAPIClient) async throws -> Void) async -> Change {
        guard await prepare() else { return .failed(errorMessage ?? AriaError.signedOut.localizedDescription) }
        do {
            try await operation(backend.api)
        } catch {
            return await failure(error, orderId: orderId)
        }
        // Dopo ogni modifica si ricarica l'ordine, anche se la modifica ha avuto effetto da sola.
        switch await detail(of: orderId) {
        case .found(let order)?: return .updated(order)
        case .gone?: return .gone
        case nil: return .failed(errorMessage ?? "")
        }
    }

    private func failure(_ error: any Error, orderId: String) async -> Change {
        if error is CancellationError || (error as? URLError)?.code == .cancelled { return .failed("") }
        switch error {
        case AriaError.http(let status, _) where status == 404:
            // Né il passo né l'ordine esistono più per questo operatore.
            orders.removeAll { $0.id == orderId }
            closedOrders.removeAll { $0.id == orderId }
            return .gone
        case AriaError.signedOut:
            backend.handle(error)
            return .failed(error.localizedDescription)
        case AriaError.workOrder(.stepNotFound, _), AriaError.workOrder(.workOrderClosed, _):
            // Un planner ha cambiato l'ordine: si ricarica, la modifica non è stata fatta.
            if case .found(let order)? = await detail(of: orderId) { replace(order) }
            return .failed(error.localizedDescription)
        default:
            return .failed(error.localizedDescription)
        }
    }

    private func replace(_ order: AriaWorkOrder) {
        if let index = orders.firstIndex(where: { $0.id == order.id }) { orders[index] = order }
        if let index = closedOrders.firstIndex(where: { $0.id == order.id }) { closedOrders[index] = order }
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
                                             body: AriaAvailabilityBody(availability: value))
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
                        URLQueryItem(name: "limit", value: "50")])
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
        // Qui si è già dentro: "le credenziali sono a posto" non c'entra, il server è solo giù.
        if case .signInHostOffline? = error as? AriaError {
            errorMessage = String(localized: "The server is offline. Try again later.")
            return
        }
        errorMessage = error.localizedDescription
    }
}
