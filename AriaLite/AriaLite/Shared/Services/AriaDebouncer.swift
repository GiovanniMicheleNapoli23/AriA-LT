//
//  AriaDebouncer.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  Rimanda un lavoro finché l'utente smette di scrivere: ogni chiamata annulla quella prima. Serve alle ricerche
//  delle liste, che non devono rifiltrare tutto a ogni tasto. Nei view model @Observable va tenuto
//  `@ObservationIgnored`.
//

import Foundation

@MainActor
final class AriaDebouncer {
    /// L'attesa dopo l'ultimo tasto prima di applicare la ricerca.
    static let searchDelay: Duration = .milliseconds(220)

    private let delay: Duration
    private var task: Task<Void, Never>?

    init(delay: Duration = AriaDebouncer.searchDelay) {
        self.delay = delay
    }

    /// Esegue `work` dopo `delay`, se nel frattempo non arriva un'altra chiamata.
    func schedule(_ work: @escaping @MainActor () -> Void) {
        task?.cancel()
        task = Task { [delay] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            work()
        }
    }

    /// Applica subito (campo svuotato, invio): niente attesa.
    func flush(_ work: @MainActor () -> Void) {
        task?.cancel()
        task = nil
        work()
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    isolated deinit { task?.cancel() }
}
