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
//  Due database: quello remoto del server e quello locale (AriaOfflineStore). Si lavora sempre sul
//  locale ("local-first"): ogni esito, foto o chiusura si scrive subito sul telefono e si vede subito,
//  anche senza rete; poi parte verso il server a lotti (AriaWorkOrderStore+Sync.swift).
//
//  • Offline (AriaNetworkMonitor) non si prova nessuna chiamata: lista, dettaglio, passi e calendario
//    vengono dalla copia locale; le modifiche aspettano in coda e restano visibili.
//  • `available` dura 12 ore: si rimanda all'apertura dell'app e a ogni ritorno in primo piano
//    (rimandare lo stesso valore riparte da 12 ore). `busy` / `off_duty` non scadono. Scelta offline,
//    la disponibilità parte appena torna la rete.
//  • La lista si ricarica all'apertura e al ritorno (non più di una volta al minuto), col pull-to-refresh
//    (sempre) e quando arriva una notifica push. Il tocco su una notifica passa da `openRequest`.
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

    /// Una modifica che il server ha rifiutato durante la sincronizzazione (non si riprova).
    struct SyncIssue: Identifiable, Equatable {
        enum Kind: Equatable {
            /// Il server ha rifiutato la modifica (es. un planner ha chiuso l'ordine o tolto il passo).
            case rejected
            /// L'ordine non è più dell'operatore: tolto con tutte le sue modifiche.
            case gone
        }

        let id = UUID()
        let kind: Kind
        let orderId: String
        let orderTitle: String?
        /// Cosa era stato fatto ("Passo segnato fatto", "Task completato"…).
        let change: String
        let message: String
    }

    private(set) var profile: AriaMobileProfile?
    private(set) var orders: [AriaWorkOrder] = []
    /// Task già chiusi (sezione "Past").
    private(set) var closedOrders: [AriaWorkOrder] = []
    private(set) var isLoadingClosed = false
    private(set) var hasLoadedClosed = false
    private(set) var closedError: String?
    private(set) var isLoading = false
    /// La lista c'è (dal server o dalla copia locale): distingue "vuota" da "non ancora caricata".
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    /// Ultimo caricamento della lista riuscito (anche in un avvio precedente).
    private(set) var lastUpdated: Date?
    private(set) var isUpdatingAvailability = false
    /// Ordine da aprire chiesto da fuori (tocco su una notifica): la lista lo apre e lo azzera.
    var openRequest: String?

    /// Modifiche ancora sul telefono.
    /// (Le quattro proprietà della coda le scrive anche AriaWorkOrderStore+Sync: niente `private(set)`.)
    var pendingCount = 0
    /// La coda sta partendo verso il server.
    var isSyncingChanges = false
    /// Ultima volta che la coda è arrivata tutta al server.
    var lastSyncedAt: Date?
    /// Modifiche rifiutate dal server: si mostrano finché l'operatore non le ha viste.
    var syncIssues: [SyncIssue] = []

    /// Disponibilità scelta dall'operatore: è quella che l'app rimanda quando si apre.
    /// Di default `available`, altrimenti l'operatore non riceverebbe mai ordini.
    private(set) var preferredAvailability: AriaAvailability

    @ObservationIgnored let backend: AriaBackend
    @ObservationIgnored let network: AriaNetworkMonitor
    @ObservationIgnored let offline: AriaOfflineStore
    /// Scarta le risposte di una lista superata (cambio filtro, nuovo refresh).
    @ObservationIgnored var generation = 0
    @ObservationIgnored var isSyncing = false
    @ObservationIgnored var flushTask: Task<Void, Never>?
    @ObservationIgnored var retryDelay = AriaWorkOrderStore.firstRetry
    /// L'account di cui sono caricati i dati locali.
    @ObservationIgnored var loadedAccount: String?
    @ObservationIgnored private var networkObserver: UUID?

    static let preferenceKey = "aria.availability_preference"
    /// La disponibilità scelta offline non è ancora arrivata al server.
    static let availabilityPendingKey = "aria.availability_pending"
    /// Una lista più fresca di così non si riscarica al ritorno in primo piano (il pull-to-refresh sì).
    static let listFreshness: TimeInterval = 60
    /// Un dettaglio più fresco di così non si riscarica aprendolo.
    static let detailFreshness: TimeInterval = 30
    /// Mentre si lavora, le modifiche aspettano questo tempo prima di partire: tocchi di fila diventano
    /// un solo lotto. Fine procedura, chiusura, uscita dall'app e ritorno della rete le mandano subito.
    /// nonisolated: è il valore di default di un parametro, che si valuta fuori dal MainActor.
    nonisolated static let batchDelay: Duration = .seconds(60)
    static let firstRetry: Duration = .seconds(30)
    static let maxRetry: Duration = .seconds(600)

    init(backend: AriaBackend, network: AriaNetworkMonitor = .shared, offline: AriaOfflineStore = .shared) {
        self.backend = backend
        self.network = network
        self.offline = offline
        preferredAvailability = UserDefaults.standard.string(forKey: Self.preferenceKey)
            .flatMap(AriaAvailability.init(rawValue:)) ?? .available
        restoreIfNeeded()
        // Torna la rete: parte la coda e, se è vecchia, si ricarica la lista.
        networkObserver = network.observe { [weak self] old, new in
            guard let self, !old.isOnline, new.isOnline else { return }
            Task { await self.sync() }
        }
    }

    /// Disponibilità mostrata: quella confermata dal server, finché non è arrivata quella scelta.
    /// Mentre il cambio è in corso (o aspetta la rete) si mostra già quello scelto.
    var availability: AriaAvailability {
        if isUpdatingAvailability || UserDefaults.standard.bool(forKey: Self.availabilityPendingKey) {
            return preferredAvailability
        }
        return profile?.availability ?? preferredAvailability
    }

    var isOffline: Bool { !network.isOnline }

    /// L'account dei dati locali: senza, niente copia né coda.
    var account: String? {
        backend.isSignedIn ? backend.mobileAccount?.id : nil
    }

    // MARK: Sincronizzazione

    /// Apertura dell'app, ritorno in primo piano, ritorno della rete: prima parte la coda (così le liste
    /// tornano già aggiornate), poi la disponibilità, poi le liste se non sono fresche.
    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        restoreIfNeeded()
        guard network.isOnline, await prepare() else { return }
        await flush()
        await syncAvailability()
        if let lastUpdated, Date.now.timeIntervalSince(lastUpdated) < Self.listFreshness { return }
        await loadOrders()
        await loadClosedOrders()
        await prefetchDetails()
    }

    /// Pull-to-refresh: sempre, se c'è rete.
    func refresh() async {
        restoreIfNeeded()
        guard network.isOnline, await prepare() else { return }
        await flush()
        await run {
            if UserDefaults.standard.bool(forKey: Self.availabilityPendingKey) {
                try await self.putAvailability(self.preferredAvailability)
            } else {
                try await self.getProfile()
            }
        }
        await loadOrders()
        await loadClosedOrders()
        await prefetchDetails()
    }

    /// Task chiusi (completati, verificati, annullati) per la sezione "Past", fino a 200: il massimo di GET /v1/mobile/work-orders.
    func loadClosedOrders() async {
        guard !isLoadingClosed, network.isOnline, await prepare(), let account else { return }
        isLoadingClosed = true
        defer { isLoadingClosed = false }
        do {
            let list = try await fetchList(status: "closed", limit: 200)
            offline.saveList(list, bucket: "closed", accountId: account)
            offline.saveValue(Data(), name: "list.closed", accountId: account)
            rebuild()
            hasLoadedClosed = true
            closedError = nil
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled { return }
            if case .signedOut? = error as? AriaError { backend.handle(error) }
            else if !AriaHTTP.isOffline(error) || !hasLoadedClosed { closedError = error.localizedDescription }
        }
    }

    /// L'operatore cambia disponibilità: si ricorda e si manda subito (o appena torna la rete).
    func setAvailability(_ value: AriaAvailability) async {
        guard value != availability, !isUpdatingAvailability else { return }
        let previous = preferredAvailability
        preferredAvailability = value
        guard network.isOnline else {
            // Offline: la scelta resta e parte al ritorno della rete.
            UserDefaults.standard.set(value.rawValue, forKey: Self.preferenceKey)
            UserDefaults.standard.set(true, forKey: Self.availabilityPendingKey)
            return
        }
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

    /// Dettaglio aggiornato (con le modifiche in coda). Offline, o se appena scaricato, quello salvato.
    /// Se l'ordine non è più dell'operatore lo toglie dalla lista.
    func detail(of id: String) async -> Detail? {
        restoreIfNeeded()
        let cached = account.flatMap { offline.order(id, accountId: $0) }
        let isFresh = cached?.detailFetchedAt.map { Date.now.timeIntervalSince($0) < Self.detailFreshness } ?? false
        guard network.isOnline, !isFresh else { return current(id).map(Detail.found) }
        guard await prepare(), let account else { return current(id).map(Detail.found) }
        do {
            let json = try await fetchDetail(id)
            offline.saveDetail(json, accountId: account)
            rebuild()
            return current(id).map(Detail.found)
        } catch AriaError.http(let status, _) where status == 404 {
            offline.removeOrder(id, accountId: account)
            rebuild()
            return .gone
        } catch {
            // Rete caduta a metà: resta quello salvato, l'avviso "offline" lo dice già.
            if !AriaHTTP.isOffline(error) || cached == nil { handle(error) }
            return current(id).map(Detail.found)
        }
    }

    // MARK: Passi, foto, completamento

    /// Esito di una modifica: l'ordine aggiornato, oppure l'ordine non è più dell'operatore,
    /// oppure il messaggio dell'errore (la modifica non è stata fatta).
    enum Change {
        case updated(AriaWorkOrder)
        case gone
        case failed(String)
    }

    /// Mette (o cambia) il risultato di un passo. Si salva sul telefono e parte col prossimo lotto.
    func report(_ result: AriaStepResult, step stepId: String, of orderId: String) async -> Change {
        let (status, note): (String, String?) = switch result {
        case .done(let note): ("done", note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty)
        case .notDone(let note): ("not_done", note.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        // Gli stessi controlli del server (422), prima di mettere in coda qualcosa che verrebbe rifiutato.
        if status == "not_done", note?.isEmpty ?? true { return .failed(AriaServerCode.noteRequired.localized) }
        if (note?.count ?? 0) > 2000 { return .failed(AriaServerCode.noteTooLong.localized) }
        return await enqueue(.report(stepId: stepId, status: status, note: note, at: .now), orderId: orderId)
    }

    /// Annulla il risultato di un passo (e le sue foto).
    func clearReport(step stepId: String, of orderId: String) async -> Change {
        await enqueue(.clearReport(stepId: stepId), orderId: orderId)
    }

    /// Aggiunge una foto (JPEG) a un passo che ha già un risultato. Resta sul telefono finché non parte.
    func addPhoto(jpeg: Data, step stepId: String, of orderId: String) async -> Change {
        guard jpeg.count <= 10 * 1024 * 1024 else { return .failed(AriaServerCode.photoTooLarge.localized) }
        if let order = current(orderId), let step = order.procedure?.steps.first(where: { $0.id == stepId }) {
            guard step.report != nil else { return .failed(AriaServerCode.stepNotReported.localized) }
            let count = step.report?.photos.count ?? 0
            guard count + pendingPhotos(step: stepId, of: orderId).count < 3 else {
                return .failed(AriaServerCode.photoLimitReached.localized)
            }
        }
        let localId = AriaWorkOrderOverlay.localPhotoPrefix + UUID().uuidString
        return await enqueue(.addPhoto(stepId: stepId, localId: localId), orderId: orderId, photo: jpeg)
    }

    /// Toglie una foto: dal server, o dalla coda se non era ancora partita (`local-…`).
    func removePhoto(_ photoId: String, step stepId: String, of orderId: String) async -> Change {
        await enqueue(.removePhoto(stepId: stepId, photoId: photoId), orderId: orderId)
    }

    /// Le foto di un passo ancora sul telefono.
    func pendingPhotos(step stepId: String, of orderId: String) -> [(localId: String, jpeg: Data)] {
        guard let account else { return [] }
        return offline.pendingPhotos(orderId: orderId, stepId: stepId, accountId: account)
    }

    /// Chiude l'ordine: è la fine della procedura, quindi parte subito tutto il lotto.
    /// Online gli errori del server (es. `steps_incomplete`) arrivano qui; offline la chiusura aspetta in coda.
    func complete(_ orderId: String, resolutionNotes: String) async -> Change {
        let notes = resolutionNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !notes.isEmpty else { return .failed(AriaServerCode.resolutionNotesRequired.localized) }
        if let procedure = current(orderId)?.procedure, !procedure.isFullyReported {
            return .failed(AriaServerCode.stepsIncomplete.localized)
        }
        let change = await enqueue(.complete(notes: notes, at: .now), orderId: orderId, flushDelay: nil)
        guard case .updated = change, network.isOnline else { return change }
        let issuesBefore = syncIssues.count
        await flush()
        // Rifiutata dal server adesso: lo si dice qui, non come problema di sincronizzazione.
        if let issue = syncIssues.dropFirst(issuesBefore).first(where: { $0.orderId == orderId }) {
            syncIssues.removeAll { $0.id == issue.id }
            if case .gone = issue.kind { return .gone }
            return .failed(issue.message)
        }
        guard account.map({ offline.order(orderId, accountId: $0) != nil }) ?? false else { return .gone }
        return current(orderId).map(Change.updated) ?? .gone
    }

    /// Mette una modifica in coda, aggiorna subito le liste e programma il lotto.
    /// `flushDelay` nil = parte subito (la chiama chi lo decide, es. `complete`).
    private func enqueue(_ change: AriaPendingChange, orderId: String, photo: Data? = nil,
                         flushDelay: Duration? = AriaWorkOrderStore.batchDelay) async -> Change {
        restoreIfNeeded()
        guard let account else { return .failed(AriaError.signedOut.localizedDescription) }
        // L'ordine deve essere sul telefono: è da lì che si sa com'è fatto e cosa mostrare.
        if offline.order(orderId, accountId: account) == nil {
            guard case .found? = await detail(of: orderId) else {
                return .failed(String(localized: "This task isn't saved on the phone yet. Open it once while online."))
            }
        }
        if let order = current(orderId), order.isClosed, !change.isComplete {
            return .failed(AriaServerCode.workOrderClosed.localized)
        }
        let serverReported = AriaWorkOrderOverlay.reportedStepIds(in: offline.order(orderId, accountId: account)?.merged)
        offline.enqueue(change, orderId: orderId, photo: photo, accountId: account,
                        serverHasReport: { serverReported.contains($0) })
        rebuild()
        if let flushDelay { scheduleFlush(after: flushDelay) }
        return current(orderId).map(Change.updated) ?? .failed("")
    }

    /// L'ordine come si vede adesso: copia locale + coda.
    func current(_ id: String) -> AriaWorkOrder? {
        orders.first { $0.id == id } ?? closedOrders.first { $0.id == id }
    }

    /// Da scollegati non resta niente dell'operatore precedente. `keepOfflineWork`: la sessione è finita
    /// da sola (scaduta, revocata) e la coda resta per quando lo stesso operatore rientra.
    func reset(keepOfflineWork: Bool = false) {
        generation += 1
        flushTask?.cancel()
        flushTask = nil
        if !keepOfflineWork { offline.wipe() }
        loadedAccount = nil
        profile = nil
        openRequest = nil
        orders = []
        closedOrders = []
        hasLoadedClosed = false
        closedError = nil
        hasLoaded = false
        isLoading = false
        errorMessage = nil
        lastUpdated = nil
        pendingCount = 0
        syncIssues = []
        lastSyncedAt = nil
    }

    func dismissError() { errorMessage = nil }

    func dismissSyncIssues() { syncIssues = [] }

    // MARK: Copia locale

    /// Carica i dati salvati dell'account entrato (al primo uso e a ogni cambio di account).
    func restoreIfNeeded() {
        guard let account, account != loadedAccount else { return }
        loadedAccount = account
        // Un altro operatore sullo stesso telefono non eredita niente.
        offline.keepOnly(accountId: account)
        profile = offline.value("me", accountId: account)
            .flatMap { try? JSONDecoder().decode(AriaMobileProfile.self, from: $0.data) }
        let openList = offline.value("list.open", accountId: account)
        hasLoaded = openList != nil
        lastUpdated = openList?.fetchedAt
        hasLoadedClosed = offline.value("list.closed", accountId: account) != nil
        rebuild()
    }

    /// Ricalcola le liste dalla copia locale con la coda applicata.
    func rebuild() {
        guard let account else { return }
        let queue = offline.queue(accountId: account)
        let changes = Dictionary(grouping: queue, by: \.orderId)
        var open: [(rank: Int, order: AriaWorkOrder)] = []
        var closed: [(rank: Int, order: AriaWorkOrder)] = []
        for cached in offline.orders(accountId: account) {
            guard let base = cached.merged else { continue }
            let json = AriaWorkOrderOverlay.apply(changes[cached.orderId]?.map(\.change) ?? [], to: base)
            guard let order = try? json.decoded(as: AriaWorkOrder.self) else { continue }
            if order.isClosed {
                // Chiuso qui ma ancora nella lista degli aperti del server: è il più recente, va in cima.
                closed.append((cached.bucket == "closed" ? cached.position : -1_000_000 + cached.position, order))
            } else {
                // Un ordine visto solo nel dettaglio (es. da una notifica) va in fondo.
                open.append((cached.position < 0 ? Int.max : cached.position, order))
            }
        }
        orders = open.sorted { $0.rank < $1.rank }.map(\.order)
        closedOrders = closed.sorted { $0.rank < $1.rank }.map(\.order)
        pendingCount = queue.count
    }

    // MARK: Privato

    /// Ogni chiamata /v1/mobile vuole il Company-Id (400 senza): lo dà GET /v1/companies.
    func prepare() async -> Bool {
        guard backend.isSignedIn else { return false }
        await backend.bootstrapIfNeeded()
        guard backend.isSignedIn else { return false }
        guard backend.activeCompanyId != nil else {
            errorMessage = backend.lastError ?? AriaError.missingCompany.localizedDescription
            return false
        }
        return true
    }

    /// Rinnova `available` (12 ore) o manda la scelta fatta offline; altrimenti legge solo il profilo.
    private func syncAvailability() async {
        await run {
            if self.preferredAvailability == .available || UserDefaults.standard.bool(forKey: Self.availabilityPendingKey) {
                try await self.putAvailability(self.preferredAvailability)
            } else {
                try await self.getProfile()
            }
        }
    }

    private func putAvailability(_ value: AriaAvailability) async throws {
        let raw = try await backend.api.data("PUT", "v1/mobile/me/availability",
                                             body: try JSONEncoder().encode(AriaAvailabilityBody(availability: value)))
        try saveProfile(raw)
        UserDefaults.standard.removeObject(forKey: Self.availabilityPendingKey)
    }

    private func getProfile() async throws {
        try saveProfile(try await backend.api.data("GET", "v1/mobile/me"))
    }

    private func saveProfile(_ raw: Data) throws {
        do { profile = try JSONDecoder().decode(AriaMobileProfile.self, from: raw) }
        catch { throw AriaError.decoding("AriaMobileProfile: \(error)") }
        if let account { offline.saveValue(raw, name: "me", accountId: account) }
    }

    func fetchList(status: String, limit: Int) async throws -> [AriaJSON] {
        let raw = try await backend.api.data("GET", "v1/mobile/work-orders",
                                             query: [URLQueryItem(name: "status", value: status),
                                                     URLQueryItem(name: "limit", value: String(limit))])
        // Si decodifica comunque con il modello: una risposta che l'app non sa leggere non sostituisce la copia buona.
        do { _ = try JSONDecoder().decode(AriaWorkOrderList.self, from: raw) }
        catch { throw AriaError.decoding("AriaWorkOrderList: \(error)") }
        guard let orders = AriaWorkOrderOverlay.orders(inList: raw) else { throw AriaError.decoding("AriaWorkOrderList") }
        return orders
    }

    func fetchDetail(_ id: String) async throws -> AriaJSON {
        let raw = try await backend.api.data("GET", "v1/mobile/work-orders/\(id)")
        do { _ = try JSONDecoder().decode(AriaWorkOrder.self, from: raw) }
        catch { throw AriaError.decoding("AriaWorkOrder: \(error)") }
        return try JSONDecoder().decode(AriaJSON.self, from: raw)
    }

    private func loadOrders() async {
        guard let account else { return }
        generation += 1
        let current = generation
        isLoading = true
        defer { if current == generation { isLoading = false } }
        do {
            let list = try await fetchList(status: "open", limit: 50)
            guard current == generation else { return }
            offline.saveList(list, bucket: "open", accountId: account)
            offline.saveValue(Data(), name: "list.open", accountId: account)
            rebuild()
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

    func handle(_ error: any Error) {
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

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
