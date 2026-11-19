//
//  AdminUsageAutosave.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il motore del salvataggio automatico delle schede dei destinatari e delle regole degli avvisi (`useAutosave` della web):
//  una richiesta alla volta, in attesa solo l'ultima modifica (ogni PUT manda l'insieme intero, due in volo potrebbero
//  arrivare in disordine), il valore fallito tenuto per "Retry", e "blocked" quando un valore sulla scheda va corretto
//  prima. Lo possiede il view model, non la vista: un salvataggio in volo non si annulla quando la scheda sparisce.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminUsageAutosave<Value: Sendable> {
    /// Quanto resta "Saved" prima di tornare a riposo.
    static var savedDuration: Duration { .milliseconds(2500) }

    private(set) var state: AdminUsageSaveState = .idle
    /// Manda un valore e dice se il server l'ha accettato. Non lancia: il view model decide cosa fare di un errore.
    @ObservationIgnored var send: (Value) async -> Bool = { _ in true }

    @ObservationIgnored private var pending: Value?
    @ObservationIgnored private var failed: Value?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var savedTask: Task<Void, Never>?
    @ObservationIgnored private var isBlocked = false
    /// Cresce a ogni `reset()`: l'esito di una richiesta partita prima non scrive più.
    @ObservationIgnored private var generation = 0

    init() {}

    /// Una richiesta è in volo o in attesa.
    var isBusy: Bool { task != nil || pending != nil }

    /// Salva questo valore appena nessun'altra richiesta è in volo; se ce n'è una, questo prende il posto di un eventuale
    /// valore già in attesa.
    func schedule(_ value: Value) {
        pending = value
        isBlocked = false
        run()
    }

    /// "Retry": rimanda l'ultimo valore fallito.
    func retry() {
        guard let value = failed else { return }
        schedule(value)
    }

    /// Un valore sulla scheda non si può salvare: niente parte, "Not saved" senza "Retry". Con `false` si sblocca.
    func block(_ on: Bool) {
        if on {
            pending = nil
            isBlocked = true
            savedTask?.cancel()
            // Una richiesta in volo finisce prima; poi resta "blocked".
            if task == nil { state = .blocked }
        } else if isBlocked {
            isBlocked = false
            if task == nil, state == .blocked { state = .idle }
        }
    }

    /// Dimentica tutto (uscita dall'account o cambio di azienda). Una richiesta in volo finisce da sola, ma il suo esito
    /// non lo guarda più nessuno.
    func reset() {
        generation += 1
        pending = nil
        failed = nil
        isBlocked = false
        savedTask?.cancel()
        savedTask = nil
        task = nil
        state = .idle
    }

    /// Aspetta che la coda si svuoti (per i test).
    func settled() async {
        while let current = task {
            await current.value
        }
    }

    // MARK: Interno

    private func run() {
        guard task == nil, let value = pending else { return }
        pending = nil
        failed = nil
        savedTask?.cancel()
        state = .saving
        let generation = self.generation
        task = Task { [weak self] in
            guard let self else { return }
            let accepted = await self.send(value)
            self.finish(value, accepted: accepted, generation: generation)
        }
    }

    private func finish(_ value: Value, accepted: Bool, generation: Int) {
        // Un `reset()` ha già buttato la richiesta: non scrive più.
        guard generation == self.generation else { return }
        task = nil
        if !accepted { failed = value }
        if pending != nil {
            run()
            return
        }
        // Nel frattempo un valore sulla scheda è diventato non valido: resta "blocked".
        if isBlocked {
            state = .blocked
            return
        }
        guard accepted else {
            state = .error
            return
        }
        state = .saved
        savedTask = Task { [weak self] in
            try? await Task.sleep(for: Self.savedDuration)
            guard !Task.isCancelled, let self, self.state == .saved else { return }
            self.state = .idle
        }
    }
}
