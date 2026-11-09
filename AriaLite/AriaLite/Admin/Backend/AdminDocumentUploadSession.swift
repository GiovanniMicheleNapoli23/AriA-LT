//
//  AdminDocumentUploadSession.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  La URLSession in background dei documenti: l'invio lo fa il sistema, anche con l'app sospesa o chiusa.
//  Unica per l'app (iOS la riaggancia per identificatore) e senza cookie come AriaHTTP.cookielessSession.
//  L'esito si scrive subito sul disco (AdminDocumentUploadStore), anche se nessuno ascolta: l'app può essere
//  stata riaperta dal sistema solo per ricevere la fine. Poi, se c'è, lo dice ad AdminDocumentUploadCenter.
//

import Foundation
import Synchronization

nonisolated final class AdminDocumentUploadSession: NSObject, URLSessionDataDelegate, Sendable {
    static let shared = AdminDocumentUploadSession(store: .shared)
    static let identifier = (Bundle.main.bundleIdentifier ?? "AriaLite") + ".document-uploads"

    enum Outcome: Sendable {
        case uploaded
        /// 401: il token è scaduto durante l'attesa; si può riprovare con uno nuovo.
        case unauthorized
        case failed(any Error)
    }

    enum Event: Sendable {
        case progress(UUID, Double)
        case finished(UUID, Outcome)
    }

    private struct State {
        var session: URLSession?
        /// Le risposte, per leggere l'errore del server.
        var responses: [Int: Data] = [:]
        /// L'ultima frazione mandata, per non svegliare il main actor a ogni pacchetto.
        var reported: [Int: Double] = [:]
        var listener: (@Sendable (Event) -> Void)?
        /// Da chiamare quando il sistema ha consegnato tutti gli eventi (app riaperta in background).
        var finishEvents: (@Sendable () -> Void)?
    }

    private let state = Mutex(State())
    private let store: AdminDocumentUploadStore

    init(store: AdminDocumentUploadStore) {
        self.store = store
    }

    /// Creata alla prima richiesta: un account che non carica niente non la apre mai.
    private var session: URLSession {
        state.withLock { state in
            if let session = state.session { return session }
            let configuration = URLSessionConfiguration.background(withIdentifier: Self.identifier)
            configuration.sessionSendsLaunchEvents = true
            configuration.isDiscretionary = false
            configuration.httpShouldSetCookies = false
            configuration.httpCookieAcceptPolicy = .never
            configuration.httpCookieStorage = nil
            configuration.urlCache = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
            state.session = session
            return session
        }
    }

    func setListener(_ listener: (@Sendable (Event) -> Void)?) {
        state.withLock { $0.listener = listener }
    }

    // MARK: Comandi

    func enqueue(_ request: URLRequest, jobId: UUID) {
        let task = session.uploadTask(with: request, fromFile: store.bodyURL(for: jobId))
        task.taskDescription = jobId.uuidString
        task.resume()
    }

    /// I job che il sistema sta ancora inviando, con la frazione già inviata.
    func liveJobs() async -> [UUID: Double] {
        var live: [UUID: Double] = [:]
        for task in await session.allTasks where task.state == .running || task.state == .suspended {
            guard let id = task.taskDescription.flatMap(UUID.init(uuidString:)) else { continue }
            live[id] = Self.fraction(sent: task.countOfBytesSent, expected: task.countOfBytesExpectedToSend)
        }
        return live
    }

    func cancel(_ jobId: UUID) async {
        for task in await session.allTasks where task.taskDescription == jobId.uuidString { task.cancel() }
    }

    func cancelAll() async {
        for task in await session.allTasks { task.cancel() }
    }

    /// Dall'app delegate: il sistema ha riaperto l'app per gli eventi di questa sessione.
    func handleEvents(completion: @escaping @Sendable () -> Void) {
        state.withLock { $0.finishEvents = completion }
        // Riagganciarsi all'identificatore fa arrivare gli eventi in sospeso.
        _ = session
    }

    // MARK: URLSessionDataDelegate

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard let id = Self.jobId(of: task) else { return }
        let fraction = Self.fraction(sent: totalBytesSent, expected: totalBytesExpectedToSend)
        let listener = state.withLock { state -> (@Sendable (Event) -> Void)? in
            let last = state.reported[task.taskIdentifier] ?? -1
            guard fraction - last >= 0.01 || fraction >= 1 else { return nil }
            state.reported[task.taskIdentifier] = fraction
            return state.listener
        }
        listener?(.progress(id, fraction))
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        state.withLock { $0.responses[dataTask.taskIdentifier, default: Data()].append(data) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        let (data, listener) = state.withLock { state in
            state.reported[task.taskIdentifier] = nil
            return (state.responses.removeValue(forKey: task.taskIdentifier) ?? Data(), state.listener)
        }
        guard let id = Self.jobId(of: task) else { return }
        let outcome = Self.outcome(response: task.response, data: data, error: error)
        switch outcome {
        case .uploaded:
            store.remove(id)
        case .unauthorized:
            store.markFailed(id, message: AriaError.signedOut.localizedDescription)
        case .failed(let error):
            store.markFailed(id, message: error.localizedDescription)
        }
        listener?(.finished(id, outcome))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(AriaRedirectGuard.redirect(request, from: task.originalRequest))
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        guard let finish = state.withLock({ state in
            defer { state.finishEvents = nil }
            return state.finishEvents
        }) else { return }
        // UIKit vuole il completion handler sul main thread.
        DispatchQueue.main.async { finish() }
    }

    // MARK: Lettura

    static func outcome(response: URLResponse?, data: Data, error: (any Error)?) -> Outcome {
        if let error { return .failed(error) }
        guard let response else { return .failed(URLError(.badServerResponse)) }
        if (response as? HTTPURLResponse)?.statusCode == 401 { return .unauthorized }
        if let offline = AriaHTTP.hostDownError(response) { return .failed(offline) }
        do {
            try AriaHTTP.check(response, data)
            return .uploaded
        } catch {
            return .failed(error)
        }
    }

    private static func jobId(of task: URLSessionTask) -> UUID? {
        task.taskDescription.flatMap(UUID.init(uuidString:))
    }

    private static func fraction(sent: Int64, expected: Int64) -> Double {
        expected > 0 ? min(1, Double(sent) / Double(expected)) : 0
    }
}
