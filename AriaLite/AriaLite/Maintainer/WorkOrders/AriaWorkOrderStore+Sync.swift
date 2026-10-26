//
//  AriaWorkOrderStore+Sync.swift
//  AriaLite
//
//  Created by Giovanni Michele on 19/10/26.
//
//  Come la coda delle modifiche arriva al server, con meno chiamate (e meno batteria) possibile:
//
//  • A lotti. Mentre si lavora le modifiche aspettano `batchDelay` dall'ultima: tocchi di fila partono
//    insieme. Partono subito alla fine della procedura (chiusura dell'ordine, uscita dall'esecuzione),
//    quando l'app va in background, al ritorno in primo piano e al ritorno della rete.
//  • Già fuse in coda (AriaWorkOrderOverlay.plan): due esiti dello stesso passo sono un PUT solo, una
//    foto aggiunta e tolta offline non parte, un "togli" annulla quello che non era ancora partito.
//  • Una sola rilettura per ordine a fine lotto (prima era una dopo ogni passo): serve per gli URL
//    delle foto e per quello che può aver cambiato un planner.
//  • In ordine: un passo prima delle sue foto, tutti i passi prima della chiusura.
//  • Errori: rete o server giù (5xx, 429) = si riprova più tardi, con attese crescenti (30 s → 10 min);
//    un rifiuto del server (passo tolto, ordine chiuso, limite foto…) = la modifica si scarta e si dice
//    all'operatore (`syncIssues`); 404 sull'ordine = non è più suo, si toglie con tutta la sua coda.
//  • Prefetch: dopo la lista si scaricano solo i dettagli cambiati sul server (o mai scaricati), così
//    la procedura c'è anche offline. Con "Risparmio dati" niente prefetch.
//

import Foundation
import UIKit

extension AriaWorkOrderStore {
    /// Manda la coda adesso (se c'è rete). Restituisce quando ha finito o si è fermata.
    func flush() async {
        flushTask?.cancel()
        flushTask = nil
        guard !isSyncingChanges, network.isOnline, let account, !offline.queue(accountId: account).isEmpty,
              await prepare() else { return }
        isSyncingChanges = true
        defer { isSyncingChanges = false }

        var touched: [String] = []
        /// Ordini chiusi in questo lotto: la risposta del server è già l'ordine aggiornato.
        var closed = Set<String>()
        var stoppedEarly = false

        while let next = offline.queue(accountId: account).first {
            do {
                try await send(next, account: account)
                offline.remove([next.id])
                if next.change.isComplete { closed.insert(next.orderId) }
                if !touched.contains(next.orderId) { touched.append(next.orderId) }
            } catch {
                switch Self.classify(error) {
                case .cancelled:
                    stoppedEarly = true
                case .retryLater:
                    offline.markAttempt(next.id, error: error.localizedDescription)
                    stoppedEarly = true
                case .signedOut:
                    backend.handle(error)
                    stoppedEarly = true
                case .orderGone:
                    let title = current(next.orderId)?.title
                    offline.removeOrder(next.orderId, accountId: account)
                    touched.removeAll { $0 == next.orderId }
                    syncIssues.append(SyncIssue(kind: .gone, orderId: next.orderId, orderTitle: title,
                                                change: next.change.summary,
                                                message: String(localized: "This task is no longer assigned to you.")))
                case .rejected(let message):
                    offline.remove([next.id])
                    if !touched.contains(next.orderId) { touched.append(next.orderId) }
                    syncIssues.append(SyncIssue(kind: .rejected, orderId: next.orderId, orderTitle: current(next.orderId)?.title,
                                                change: next.change.summary, message: message))
                }
            }
            pendingCount = offline.pendingCount(accountId: account)
            if stoppedEarly { break }
        }

        // Una rilettura per ordine toccato (non per modifica).
        for id in touched where !closed.contains(id) {
            if let json = try? await fetchDetail(id) { offline.saveDetail(json, accountId: account) }
        }
        rebuild()

        if stoppedEarly {
            scheduleRetry()
        } else {
            retryDelay = Self.firstRetry
            lastSyncedAt = .now
        }
    }

    /// Il prossimo lotto tra `delay` (sostituisce quello programmato). Offline non serve: parte al ritorno della rete.
    func scheduleFlush(after delay: Duration) {
        flushTask?.cancel()
        guard network.isOnline else { return }
        flushTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            // `flush` annulla il lotto programmato: non deve annullare se stesso (le chiamate fallirebbero).
            self.flushTask = nil
            await self.flush()
        }
    }

    /// L'app va in background: il lotto parte subito, con il tempo extra che iOS concede.
    func flushForBackground() async {
        guard pendingCount > 0, network.isOnline else { return }
        // Se il tempo finisce prima, iOS chiama la scadenza: il task si chiude lì e la coda resta per dopo.
        let box = BackgroundTaskBox()
        box.id = UIApplication.shared.beginBackgroundTask(withName: "aria.sync") {
            UIApplication.shared.endBackgroundTask(box.id)
            box.id = .invalid
        }
        await flush()
        if box.id != .invalid { UIApplication.shared.endBackgroundTask(box.id) }
    }

    private func scheduleRetry() {
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, Self.maxRetry)
        scheduleFlush(after: delay)
    }

    // MARK: Invio

    private func send(_ queued: AriaQueuedChange, account: String) async throws {
        let api = backend.api
        let orderId = queued.orderId
        switch queued.change {
        case .report(let stepId, let status, let note, _):
            let result: AriaStepResult = status == "done" ? .done(note: note) : .notDone(note: note ?? "")
            _ = try await api.report(result, step: stepId, of: orderId)
        case .clearReport(let stepId):
            try await api.clearReport(step: stepId, of: orderId)
        case .addPhoto(let stepId, _):
            // Senza il file (non dovrebbe succedere) non c'è niente da caricare.
            guard let jpeg = offline.photo(for: queued.id) else { return }
            _ = try await api.addPhoto(jpeg: jpeg, step: stepId, of: orderId)
        case .removePhoto(let stepId, let photoId):
            _ = try await api.removePhoto(photoId, step: stepId, of: orderId)
        case .complete(let notes, _):
            let raw = try await api.completeData(order: orderId, resolutionNotes: notes)
            // La risposta è l'ordine chiuso: diventa il dettaglio salvato, senza rileggerlo.
            if let json = try? JSONDecoder().decode(AriaJSON.self, from: raw) { offline.saveDetail(json, accountId: account) }
        }
    }

    enum SyncFailure: Equatable {
        case cancelled
        /// Rete o server: la modifica resta in coda.
        case retryLater
        case signedOut
        /// 404 sull'ordine: non è più dell'operatore.
        case orderGone
        /// Il server non la accetterà mai così: si scarta.
        case rejected(String)
    }

    static func classify(_ error: any Error) -> SyncFailure {
        if error is CancellationError || (error as? URLError)?.code == .cancelled { return .cancelled }
        if AriaHTTP.isOffline(error) { return .retryLater }
        switch error {
        case AriaError.signedOut:
            return .signedOut
        case AriaError.workOrder(let code, _):
            // La foto non è arrivata o lo storage è giù: si riprova, non è un rifiuto.
            if code == .photoNotUploaded || code == .storageUnavailable { return .retryLater }
            return .rejected(code.localized)
        case AriaError.http(let status, _) where status == 404:
            return .orderGone
        case AriaError.http(let status, _) where status == 429 || status >= 500:
            return .retryLater
        case AriaError.http:
            return .rejected(error.localizedDescription)
        default:
            return .retryLater
        }
    }

    // MARK: Prefetch

    /// Scarica i dettagli degli ordini aperti cambiati sul server dall'ultima volta (o mai scaricati),
    /// tre alla volta. Gli errori si ignorano: il dettaglio si riprova quando l'operatore lo apre.
    /// `rebuilding: false` lascia il rebuild a chi chiama. Restituisce se la copia locale è cambiata.
    @discardableResult
    func prefetchDetails(rebuilding: Bool = true) async -> Bool {
        guard network.isOnline, !network.status.isConstrained, let account else { return false }
        let stale = offline.orders(accountId: account).filter { cached in
            guard cached.bucket == "open" else { return false }
            guard let detail = cached.detail else { return true }
            let listStamp = cached.list?["updatedAt"]?.stringValue.flatMap(AriaWireDate.parse)
            let detailStamp = detail["updatedAt"]?.stringValue.flatMap(AriaWireDate.parse)
            if let listStamp, let detailStamp { return listStamp > detailStamp }
            // Senza date non si sa se è cambiato: si riscarica se ha più di un giorno.
            return Date.now.timeIntervalSince(cached.detailFetchedAt ?? .distantPast) > 24 * 3600
        }.map(\.orderId)
        guard !stale.isEmpty else { return false }

        let api = backend.api
        var fetched: [AriaJSON] = []
        // Rete, controllo col modello e decodifica stanno dentro il task (fuori dal main thread).
        await withTaskGroup(of: AriaJSON?.self) { group in
            var pending = stale[...]
            func addNext() {
                guard let id = pending.popFirst() else { return }
                group.addTask {
                    try? await api.workOrderJSON(id: id)
                }
            }
            for _ in 0..<3 { addNext() }
            for await json in group {
                if let json { fetched.append(json) }
                addNext()
            }
        }
        // Un solo commit per tutti i dettagli (prima uno per ordine).
        offline.saveDetails(fetched, accountId: account)
        if rebuilding { rebuild() }
        return true
    }
}

/// L'id del tempo extra in background, condiviso tra chi lo chiude: la fine del lotto o la scadenza.
private final class BackgroundTaskBox {
    var id: UIBackgroundTaskIdentifier = .invalid
}
