//
//  AriaWorkOrderOverlay.swift
//  AriaLite
//
//  Created by Giovanni Michele on 19/10/26.
//
//  Le modifiche dell'operatore ancora sul telefono (coda verso il server) e come si vedono prima di
//  arrivare: si applicano al JSON dell'ordine salvato, poi si decodifica con i modelli di sempre.
//  Così lista, dettaglio, esecuzione dei passi e calendario mostrano subito il lavoro fatto, anche
//  offline, e lo continuano a mostrare sopra i dati freschi del server finché la coda non è vuota.
//
//  Tutto qui è puro (niente rete, niente database): lo usano AriaOfflineStore e i test.
//

import Foundation

/// Una modifica da mandare al server. L'ordine di arrivo conta (un passo prima delle sue foto,
/// tutti i passi prima del completamento): la coda si svuota in ordine.
nonisolated enum AriaPendingChange: Codable, Sendable, Equatable {
    /// PUT …/steps/{id}: `status` è `done` | `not_done`.
    case report(stepId: String, status: String, note: String?, at: Date)
    /// DELETE …/steps/{id}: toglie il risultato e le sue foto.
    case clearReport(stepId: String)
    /// Foto ancora sul telefono (`localId` = "local-…"); il JPEG sta nella riga della coda.
    case addPhoto(stepId: String, localId: String)
    /// DELETE …/photos/{id} di una foto già sul server.
    case removePhoto(stepId: String, photoId: String)
    /// POST …/complete.
    case complete(notes: String, at: Date)

    var stepId: String? {
        switch self {
        case .report(let id, _, _, _), .clearReport(let id), .addPhoto(let id, _), .removePhoto(let id, _): id
        case .complete: nil
        }
    }

    var isComplete: Bool {
        if case .complete = self { true } else { false }
    }

    /// Per il riepilogo degli errori di sincronizzazione.
    var summary: String {
        switch self {
        case .report(_, let status, _, _):
            status == "done" ? String(localized: "Step marked done") : String(localized: "Step marked not done")
        case .clearReport: String(localized: "Step result removed")
        case .addPhoto: String(localized: "Photo")
        case .removePhoto: String(localized: "Photo removed")
        case .complete: String(localized: "Task completed")
        }
    }
}

/// Una modifica in coda con il suo id (per toglierla o fonderla).
nonisolated struct AriaQueuedChange: Sendable, Equatable, Identifiable {
    let id: UUID
    let orderId: String
    var change: AriaPendingChange
}

nonisolated enum AriaWorkOrderOverlay {
    static let localPhotoPrefix = "local-"

    // MARK: Fusione della coda

    /// Cosa fare con una modifica nuova, data la coda di quell'ordine: meno chiamate, stesso risultato.
    struct Plan: Equatable {
        /// Modifiche in coda da togliere.
        var drop: [UUID] = []
        /// Modifica in coda da sostituire con quella nuova (stessa posizione nella coda).
        var replace: UUID?
        /// La modifica nuova va in coda (in fondo). Falso se si annulla con una già in coda.
        var enqueue = true
    }

    /// - `serverHasReport`: il passo ha un risultato sul server (dall'ultimo JSON scaricato, senza la coda).
    static func plan(_ new: AriaPendingChange, queue: [AriaQueuedChange], serverHasReport: (String) -> Bool) -> Plan {
        var plan = Plan()
        switch new {
        case .report(let stepId, _, _, _):
            // Due esiti dello stesso passo: conta l'ultimo (il PUT è idempotente e sostituisce).
            // Solo se non c'è un "togli" in mezzo: il DELETE cancella anche le foto, il PUT no.
            if let last = queue.last(where: { $0.change.stepId == stepId && !isPhoto($0.change) }),
               case .report = last.change {
                plan.replace = last.id
            }
        case .clearReport(let stepId):
            // Tutto quello in coda per il passo diventa inutile: esito, foto da caricare, foto da togliere.
            plan.drop = queue.filter { $0.change.stepId == stepId }.map(\.id)
            // Al server serve il DELETE solo se lì c'è qualcosa da togliere.
            let queuedClear = queue.contains { if case .clearReport(stepId) = $0.change { true } else { false } }
            plan.enqueue = serverHasReport(stepId) || queuedClear
        case .removePhoto(let stepId, let photoId) where photoId.hasPrefix(localPhotoPrefix):
            // Foto mai partita: basta toglierla dalla coda.
            plan.drop = queue.filter {
                if case .addPhoto(stepId, photoId) = $0.change { true } else { false }
            }.map(\.id)
            plan.enqueue = false
        case .complete:
            if let existing = queue.first(where: { $0.change.isComplete }) { plan.replace = existing.id }
        case .addPhoto, .removePhoto:
            break
        }
        return plan
    }

    private static func isPhoto(_ change: AriaPendingChange) -> Bool {
        switch change {
        case .addPhoto, .removePhoto: true
        default: false
        }
    }

    // MARK: Unione lista + dettaglio

    /// La lista e il dettaglio dello stesso ordine arrivano in momenti diversi: nei campi comuni vince
    /// quello aggiornato più di recente sul server (`updatedAt`), a pari merito quello scaricato dopo.
    /// La procedura c'è solo nel dettaglio e resta anche se il dettaglio è più vecchio: meglio uno step
    /// un po' vecchio che niente da fare offline (online il dettaglio si riscarica appena serve).
    static func merge(list: AriaJSON?, listFetchedAt: Date?, detail: AriaJSON?, detailFetchedAt: Date?) -> AriaJSON? {
        guard let list = list?.objectValue else { return detail }
        guard let detail = detail?.objectValue else { return .object(list) }
        let listStamp = list["updatedAt"]?.stringValue.flatMap(AriaWireDate.parse)
        let detailStamp = detail["updatedAt"]?.stringValue.flatMap(AriaWireDate.parse)
        let detailWins: Bool = switch (listStamp, detailStamp) {
        case let (l?, d?) where l != d: d > l
        default: (detailFetchedAt ?? .distantPast) >= (listFetchedAt ?? .distantPast)
        }
        return .object(detailWins ? list.merging(detail) { _, d in d } : detail.merging(list) { _, l in l })
    }

    // MARK: Applicazione

    /// Il JSON dell'ordine con le modifiche in coda applicate, nell'ordine. Le foto da caricare non
    /// finiscono qui (non hanno un URL): le mostra chi esegue i passi, dalla coda.
    static func apply(_ changes: [AriaPendingChange], to order: AriaJSON) -> AriaJSON {
        guard var object = order.objectValue, !changes.isEmpty else { return order }
        var procedure = object["procedure"]?.objectValue
        var steps = procedure?["steps"]?.arrayValue ?? []

        func updateStep(_ id: String, _ body: (inout [String: AriaJSON]) -> Void) {
            guard let index = steps.firstIndex(where: { $0["id"]?.stringValue == id }),
                  var step = steps[index].objectValue else { return }
            body(&step)
            steps[index] = .object(step)
        }

        for change in changes {
            switch change {
            case .report(let stepId, let status, let note, let at):
                updateStep(stepId) { step in
                    // Cambiare l'esito lascia le foto già caricate (come il PUT del server).
                    let photos = step["report"]?["photos"] ?? .array([])
                    step["report"] = .object([
                        "status": .string(status),
                        "note": note.map(AriaJSON.string) ?? .null,
                        "photos": photos,
                        "reportedAt": .string(iso(at)),
                    ])
                }
                // Il primo risultato porta l'ordine "in corso", come sul server.
                if let status = object["status"]?.stringValue, ["proposed", "planned", "assigned"].contains(status) {
                    object["status"] = .string("in_progress")
                }
            case .clearReport(let stepId):
                updateStep(stepId) { $0["report"] = .null }
            case .removePhoto(let stepId, let photoId):
                updateStep(stepId) { step in
                    guard var report = step["report"]?.objectValue else { return }
                    report["photos"] = .array((report["photos"]?.arrayValue ?? []).filter { $0["id"]?.stringValue != photoId })
                    step["report"] = .object(report)
                }
            case .complete(let notes, let at):
                object["status"] = .string("completed")
                object["updatedAt"] = .string(iso(at))
                if (object["notes"]?.nonEmptyString) == nil { object["notes"] = .string(notes) }
            case .addPhoto:
                break
            }
        }

        if procedure != nil {
            procedure?["steps"] = .array(steps)
            let progress = progress(of: steps)
            procedure?["progress"] = progress
            object["procedure"] = procedure.map(AriaJSON.object)
            object["progress"] = progress
        }
        return .object(object)
    }

    /// `{done, notDone, total}` ricalcolato dai passi.
    static func progress(of steps: [AriaJSON]) -> AriaJSON {
        let statuses = steps.compactMap { $0["report"]?["status"]?.stringValue }
        let done = statuses.filter { $0 == "done" }.count
        let notDone = statuses.filter { $0 == "not_done" }.count
        return .object(["done": .number(Double(done)), "notDone": .number(Double(notDone)),
                        "total": .number(Double(steps.count))])
    }

    /// I passi con un risultato nel JSON del server (senza la coda): decide se un "togli" va mandato.
    static func reportedStepIds(in order: AriaJSON?) -> Set<String> {
        let steps = order?["procedure"]?["steps"]?.arrayValue ?? []
        return Set(steps.compactMap { step in
            guard let id = step["id"]?.stringValue, let report = step["report"], report != .null else { return nil }
            return id
        })
    }

    /// Gli ordini di una risposta di GET /v1/work-orders (array, o avvolto come in AriaWorkOrderList).
    static func orders(inList raw: Data) -> [AriaJSON]? {
        guard let json = try? JSONDecoder().decode(AriaJSON.self, from: raw) else { return nil }
        if case .array(let items) = json { return items }
        for key in ["items", "workOrders", "data"] {
            if case .array(let items)? = json[key] { return items }
        }
        return nil
    }

    static func iso(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle())
    }
}
