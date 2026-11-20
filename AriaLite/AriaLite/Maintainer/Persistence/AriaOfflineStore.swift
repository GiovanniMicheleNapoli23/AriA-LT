//
//  AriaOfflineStore.swift
//  AriaLite
//
//  Created by Giovanni Michele on 19/10/26.
//
//  Il database locale dei lavori (SwiftData), accanto a quello remoto del server:
//  - la copia delle risposte del server (lista aperti/chiusi, dettagli con la procedura, profilo),
//    salvate così come arrivano (JSON) e lette con i modelli di sempre: offline lista, dettaglio,
//    passi e calendario restano consultabili;
//  - la coda delle modifiche dell'operatore (esiti dei passi, foto, chiusura), che parte verso il
//    server a lotti (AriaWorkOrderStore+Sync). Le foto stanno fuori dal database (`externalStorage`).
//
//  Ogni riga è dell'account che l'ha scritta: un altro operatore sullo stesso telefono non vede
//  niente, e una sessione scaduta non perde il lavoro ancora da mandare.
//

import Foundation
import SwiftData

// MARK: - Modelli

/// Un ordine come l'ha dato il server: la riga della lista e, se scaricato, il dettaglio.
@Model
final class AriaCachedOrder {
    /// "<account>|<ordine>".
    @Attribute(.unique) var key: String
    var accountId: String
    var orderId: String
    /// `open` | `closed`: in quale lista l'ha messo il server.
    var bucket: String
    /// Posizione nella lista del server (l'ordine è il suo).
    var position: Int
    var listPayload: Data?
    var listFetchedAt: Date?
    var detailPayload: Data?
    var detailFetchedAt: Date?

    init(accountId: String, orderId: String, bucket: String, position: Int) {
        key = "\(accountId)|\(orderId)"
        self.accountId = accountId
        self.orderId = orderId
        self.bucket = bucket
        self.position = position
    }
}

/// Una risposta singola salvata (es. il profilo `me`).
@Model
final class AriaCachedValue {
    /// "<account>|<nome>".
    @Attribute(.unique) var key: String
    var accountId: String
    var payload: Data
    var fetchedAt: Date

    init(accountId: String, name: String, payload: Data, fetchedAt: Date) {
        key = "\(accountId)|\(name)"
        self.accountId = accountId
        self.payload = payload
        self.fetchedAt = fetchedAt
    }
}

/// Una modifica in attesa di arrivare al server.
@Model
final class AriaOutboxEntry {
    @Attribute(.unique) var id: UUID
    var accountId: String
    var orderId: String
    /// Ordine di invio (crescente su tutta la coda).
    var sequence: Int
    /// `AriaPendingChange` in JSON.
    var payload: Data
    /// Il JPEG di una foto da caricare.
    @Attribute(.externalStorage) var photo: Data?
    var createdAt: Date
    var attempts: Int
    var lastError: String?

    init(id: UUID = UUID(), accountId: String, orderId: String, sequence: Int, payload: Data, photo: Data?) {
        self.id = id
        self.accountId = accountId
        self.orderId = orderId
        self.sequence = sequence
        self.payload = payload
        self.photo = photo
        createdAt = .now
        attempts = 0
    }
}

// MARK: - Archivio

final class AriaOfflineStore {
    /// Un ordine salvato, già letto dal database.
    nonisolated struct CachedOrder: Sendable {
        let orderId: String
        let bucket: String
        let position: Int
        let list: AriaJSON?
        let listFetchedAt: Date?
        let detail: AriaJSON?
        let detailFetchedAt: Date?

        /// Il JSON da mostrare (lista e dettaglio uniti), senza la coda.
        var merged: AriaJSON? {
            AriaWorkOrderOverlay.merge(list: list, listFetchedAt: listFetchedAt, detail: detail, detailFetchedAt: detailFetchedAt)
        }
    }

    /// Lo stato leggero di una riga, senza i payload: basta a sapere se la copia già decodificata è ancora buona
    /// (le date cambiano a ogni scrittura della riga) e dove va l'ordine (lista e posizione).
    nonisolated struct OrderStamp: Sendable, Equatable {
        let orderId: String
        let bucket: String
        let position: Int
        let listFetchedAt: Date?
        let detailFetchedAt: Date?
    }

    /// Una riga coi payload ancora in `Data`: la decodifica (costosa) si può fare fuori dal main thread.
    nonisolated struct RawOrder: Sendable {
        let orderId: String
        let bucket: String
        let position: Int
        let listPayload: Data?
        let listFetchedAt: Date?
        let detailPayload: Data?
        let detailFetchedAt: Date?

        func decoded() -> CachedOrder {
            CachedOrder(orderId: orderId, bucket: bucket, position: position,
                        list: listPayload.flatMap(AriaOfflineStore.json), listFetchedAt: listFetchedAt,
                        detail: detailPayload.flatMap(AriaOfflineStore.json), detailFetchedAt: detailFetchedAt)
        }
    }

    static let shared = AriaOfflineStore()

    /// Si apre al primo uso, non alla creazione: `shared` è il valore di default dello store dei lavori, che nasce
    /// all'avvio dell'app anche per un admin o dietro Face ID, e non ne ha bisogno.
    private lazy var container: ModelContainer = Self.makeContainer(inMemory: inMemory)
    private let inMemory: Bool
    private var context: ModelContext { container.mainContext }

    /// `inMemory`: niente file su disco (test e anteprime).
    init(inMemory: Bool = false) {
        self.inMemory = inMemory
    }

    private static func makeContainer(inMemory: Bool) -> ModelContainer {
        let schema = Schema([AriaCachedOrder.self, AriaCachedValue.self, AriaOutboxEntry.self])
        let config = ModelConfiguration("AriaOffline", schema: schema, isStoredInMemoryOnly: inMemory)
        if let container = try? ModelContainer(for: schema, configurations: config) {
            return container
        }
        // Archivio illeggibile: si lavora in memoria finché l'app resta aperta, ma l'app non si ferma.
        let memory = ModelConfiguration("AriaOffline", schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: memory)
    }

    // MARK: Ordini

    /// Gli ordini salvati, decodificati. `bucket`: solo `open` o solo `closed` (il prefetch guarda solo gli aperti,
    /// senza decodificare anche i duecento chiusi).
    func orders(accountId: String, bucket: String? = nil) -> [CachedOrder] {
        let rows: [AriaCachedOrder]
        if let bucket {
            rows = (try? context.fetch(FetchDescriptor<AriaCachedOrder>(
                predicate: #Predicate { $0.accountId == accountId && $0.bucket == bucket },
                sortBy: [SortDescriptor(\.position)]))) ?? []
        } else {
            rows = (try? context.fetch(FetchDescriptor<AriaCachedOrder>(
                predicate: #Predicate { $0.accountId == accountId },
                sortBy: [SortDescriptor(\.position)]))) ?? []
        }
        return rows.map { row in
            CachedOrder(orderId: row.orderId, bucket: row.bucket, position: row.position,
                        list: row.listPayload.flatMap(Self.json), listFetchedAt: row.listFetchedAt,
                        detail: row.detailPayload.flatMap(Self.json), detailFetchedAt: row.detailFetchedAt)
        }
    }

    /// Tutte le righe dell'account nell'ordine del server, senza i payload (che non vengono nemmeno letti dal database).
    func orderStamps(accountId: String) -> [OrderStamp] {
        var descriptor = FetchDescriptor<AriaCachedOrder>(predicate: #Predicate { $0.accountId == accountId },
                                                          sortBy: [SortDescriptor(\.position)])
        descriptor.propertiesToFetch = [\.orderId, \.bucket, \.position, \.listFetchedAt, \.detailFetchedAt]
        return ((try? context.fetch(descriptor)) ?? []).map {
            OrderStamp(orderId: $0.orderId, bucket: $0.bucket, position: $0.position,
                       listFetchedAt: $0.listFetchedAt, detailFetchedAt: $0.detailFetchedAt)
        }
    }

    /// Le righe di questi ordini coi payload non decodificati (una sola lettura per tutte).
    func rawOrders(ids: [String], accountId: String) -> [RawOrder] {
        guard !ids.isEmpty else { return [] }
        let descriptor = FetchDescriptor<AriaCachedOrder>(
            predicate: #Predicate { $0.accountId == accountId && ids.contains($0.orderId) },
            sortBy: [SortDescriptor(\.position)])
        return ((try? context.fetch(descriptor)) ?? []).map {
            RawOrder(orderId: $0.orderId, bucket: $0.bucket, position: $0.position,
                     listPayload: $0.listPayload, listFetchedAt: $0.listFetchedAt,
                     detailPayload: $0.detailPayload, detailFetchedAt: $0.detailFetchedAt)
        }
    }

    func order(_ orderId: String, accountId: String) -> CachedOrder? {
        guard let row = row(orderId, accountId: accountId) else { return nil }
        return CachedOrder(orderId: row.orderId, bucket: row.bucket, position: row.position,
                           list: row.listPayload.flatMap(Self.json), listFetchedAt: row.listFetchedAt,
                           detail: row.detailPayload.flatMap(Self.json), detailFetchedAt: row.detailFetchedAt)
    }

    /// Una lista appena arrivata sostituisce quella salvata. Un ordine sparito dalla lista si toglie,
    /// a meno che abbia modifiche in coda (si toglierà quando sono partite, o il server dirà 404).
    func saveList(_ orders: [AriaJSON], bucket: String, accountId: String, fetchedAt: Date = .now) {
        let existing = (try? context.fetch(FetchDescriptor<AriaCachedOrder>(
            predicate: #Predicate { $0.accountId == accountId }))) ?? []
        var byId = Dictionary(existing.map { ($0.orderId, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<String>()
        for (position, order) in orders.enumerated() {
            guard let id = order["id"]?.stringValue, seen.insert(id).inserted else { continue }
            let row = byId[id] ?? {
                let row = AriaCachedOrder(accountId: accountId, orderId: id, bucket: bucket, position: position)
                context.insert(row)
                byId[id] = row
                return row
            }()
            row.bucket = bucket
            row.position = position
            row.listPayload = Self.data(order)
            row.listFetchedAt = fetchedAt
        }
        let pending = Set(queue(accountId: accountId).map(\.orderId))
        for row in existing where row.bucket == bucket && !seen.contains(row.orderId) && !pending.contains(row.orderId) {
            context.delete(row)
        }
        commit()
    }

    func saveDetail(_ order: AriaJSON, accountId: String, fetchedAt: Date = .now) {
        var inserted: [String: AriaCachedOrder] = [:]
        applyDetail(order, accountId: accountId, fetchedAt: fetchedAt, inserted: &inserted)
        commit()
    }

    /// Più dettagli insieme (prefetch): un solo commit invece di uno per ordine.
    func saveDetails(_ orders: [AriaJSON], accountId: String, fetchedAt: Date = .now) {
        guard !orders.isEmpty else { return }
        var inserted: [String: AriaCachedOrder] = [:]
        for order in orders { applyDetail(order, accountId: accountId, fetchedAt: fetchedAt, inserted: &inserted) }
        commit()
    }

    /// L'ordine non è più dell'operatore: via dalla copia e dalla coda.
    func removeOrder(_ orderId: String, accountId: String) {
        if let row = row(orderId, accountId: accountId) { context.delete(row) }
        try? context.delete(model: AriaOutboxEntry.self,
                            where: #Predicate { $0.accountId == accountId && $0.orderId == orderId })
        commit()
    }

    // MARK: Valori

    func value(_ name: String, accountId: String) -> (data: Data, fetchedAt: Date)? {
        let key = "\(accountId)|\(name)"
        var descriptor = FetchDescriptor<AriaCachedValue>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor).first).map { ($0.payload, $0.fetchedAt) }
    }

    func saveValue(_ data: Data, name: String, accountId: String, fetchedAt: Date = .now) {
        let key = "\(accountId)|\(name)"
        var descriptor = FetchDescriptor<AriaCachedValue>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        if let row = try? context.fetch(descriptor).first {
            row.payload = data
            row.fetchedAt = fetchedAt
        } else {
            context.insert(AriaCachedValue(accountId: accountId, name: name, payload: data, fetchedAt: fetchedAt))
        }
        commit()
    }

    // MARK: Coda

    /// La coda dell'account, nell'ordine di invio.
    func queue(accountId: String) -> [AriaQueuedChange] {
        Self.queued(entries(accountId: accountId))
    }

    private static func queued(_ entries: [AriaOutboxEntry]) -> [AriaQueuedChange] {
        let decoder = JSONDecoder()
        return entries.compactMap { entry in
            guard let change = try? decoder.decode(AriaPendingChange.self, from: entry.payload) else { return nil }
            return AriaQueuedChange(id: entry.id, orderId: entry.orderId, change: change)
        }
    }

    func pendingCount(accountId: String) -> Int {
        (try? context.fetchCount(FetchDescriptor<AriaOutboxEntry>(predicate: #Predicate { $0.accountId == accountId }))) ?? 0
    }

    /// Mette una modifica in coda, fondendola con quelle già in coda per lo stesso ordine
    /// (AriaWorkOrderOverlay.plan). `serverHasReport`: il passo ha un risultato sul server.
    func enqueue(_ change: AriaPendingChange, orderId: String, photo: Data? = nil, accountId: String,
                 serverHasReport: (String) -> Bool) {
        // Le righe si leggono una volta sola: la coda dell'ordine si ricava da quelle (stesso ordine di invio).
        let all = entries(accountId: accountId)
        let orderQueue = Self.queued(all.filter { $0.orderId == orderId })
        let plan = AriaWorkOrderOverlay.plan(change, queue: orderQueue, serverHasReport: serverHasReport)
        for entry in all where plan.drop.contains(entry.id) { context.delete(entry) }
        if plan.enqueue, let payload = try? JSONEncoder().encode(change) {
            if let id = plan.replace, let entry = all.first(where: { $0.id == id }) {
                entry.payload = payload
                entry.photo = photo ?? entry.photo
                entry.attempts = 0
                entry.lastError = nil
            } else {
                let next = (all.map(\.sequence).max() ?? 0) + 1
                context.insert(AriaOutboxEntry(accountId: accountId, orderId: orderId, sequence: next,
                                               payload: payload, photo: photo))
            }
        }
        commit()
    }

    func remove(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        try? context.delete(model: AriaOutboxEntry.self, where: #Predicate { ids.contains($0.id) })
        commit()
    }

    func photo(for id: UUID) -> Data? {
        entry(id)?.photo
    }

    /// Le foto di un passo ancora da caricare, nell'ordine in cui sono state aggiunte.
    func pendingPhotos(orderId: String, stepId: String, accountId: String) -> [(localId: String, jpeg: Data)] {
        let entries = entries(accountId: accountId).filter { $0.orderId == orderId }
        let decoder = JSONDecoder()
        return entries.compactMap { entry in
            guard case .addPhoto(stepId, let localId)? = try? decoder.decode(AriaPendingChange.self, from: entry.payload),
                  let jpeg = entry.photo else { return nil }
            return (localId, jpeg)
        }
    }

    /// Il JPEG di una foto ancora da caricare (la miniatura e l'anteprima lo leggono quando servono, non a ogni disegno).
    func pendingPhoto(localId: String, orderId: String, accountId: String) -> Data? {
        let decoder = JSONDecoder()
        for entry in entries(accountId: accountId) where entry.orderId == orderId {
            if case .addPhoto(_, localId)? = try? decoder.decode(AriaPendingChange.self, from: entry.payload) {
                return entry.photo
            }
        }
        return nil
    }

    /// Un tentativo andato male che si riproverà (rete, server giù).
    func markAttempt(_ id: UUID, error: String) {
        guard let entry = entry(id) else { return }
        entry.attempts += 1
        entry.lastError = error
        commit()
    }

    // MARK: Pulizia

    /// Al cambio di account restano solo le righe di quello entrato.
    func keepOnly(accountId: String) {
        try? context.delete(model: AriaCachedOrder.self, where: #Predicate { $0.accountId != accountId })
        try? context.delete(model: AriaCachedValue.self, where: #Predicate { $0.accountId != accountId })
        try? context.delete(model: AriaOutboxEntry.self, where: #Predicate { $0.accountId != accountId })
        commit()
    }

    /// Uscita dall'account: non resta niente sul telefono.
    func wipe() {
        try? context.delete(model: AriaCachedOrder.self)
        try? context.delete(model: AriaCachedValue.self)
        try? context.delete(model: AriaOutboxEntry.self)
        commit()
    }

    // MARK: Privato

    private func row(_ orderId: String, accountId: String) -> AriaCachedOrder? {
        let key = "\(accountId)|\(orderId)"
        var descriptor = FetchDescriptor<AriaCachedOrder>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func entries(accountId: String) -> [AriaOutboxEntry] {
        let descriptor = FetchDescriptor<AriaOutboxEntry>(predicate: #Predicate { $0.accountId == accountId },
                                                          sortBy: [SortDescriptor(\.sequence)])
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Scrive il dettaglio nella riga dell'ordine (la crea se manca) senza fare commit.
    /// `inserted`: le righe create in questo giro, per non crearne due se lo stesso ordine ricompare.
    private func applyDetail(_ order: AriaJSON, accountId: String, fetchedAt: Date,
                             inserted: inout [String: AriaCachedOrder]) {
        guard let id = order["id"]?.stringValue else { return }
        let row: AriaCachedOrder
        if let existing = inserted[id] ?? self.row(id, accountId: accountId) {
            row = existing
        } else {
            let closed = ["completed", "verified", "cancelled"].contains(order["status"]?.stringValue ?? "")
            row = AriaCachedOrder(accountId: accountId, orderId: id, bucket: closed ? "closed" : "open", position: -1)
            context.insert(row)
            inserted[id] = row
        }
        row.detailPayload = Self.data(order)
        row.detailFetchedAt = fetchedAt
    }

    private func entry(_ id: UUID) -> AriaOutboxEntry? {
        var descriptor = FetchDescriptor<AriaOutboxEntry>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func commit() {
        try? context.save()
    }

    nonisolated private static func json(_ data: Data) -> AriaJSON? {
        try? JSONDecoder().decode(AriaJSON.self, from: data)
    }

    private static func data(_ json: AriaJSON) -> Data? {
        try? JSONEncoder().encode(json)
    }
}
