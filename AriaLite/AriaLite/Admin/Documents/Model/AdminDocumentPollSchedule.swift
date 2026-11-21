//
//  AdminDocumentPollSchedule.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  Il ritmo con cui lista e dettaglio dei documenti si riaggiornano da soli mentre qualcosa è in elaborazione:
//  4, 8, 15, poi 30 secondi. Appena cambia qualcosa (uno stato, un avanzamento) riparte da 4. Dopo 10 minuti
//  a 30 secondi senza novità smette: tirare per aggiornare o tornare nell'app lo riaccende.
//

import Foundation

nonisolated struct AdminDocumentPollSchedule: Sendable, Equatable {
    /// Le attese fra un giro e il successivo, finché non cambia niente.
    static let steps: [Duration] = [.seconds(4), .seconds(8), .seconds(15), .seconds(30)]
    /// Quanti giri a passo massimo (30 s) senza novità prima di smettere: 10 minuti.
    static let maxIdleTicks = 20

    private var step = 0
    private var idleTicksAtMax = 0

    /// Quanto aspettare prima del prossimo giro.
    var delay: Duration { Self.steps[step] }

    /// Troppo tempo senza novità: il ciclo si ferma.
    var isExhausted: Bool { idleTicksAtMax >= Self.maxIdleTicks }

    /// Registra l'esito di un giro: con novità si riparte dal passo più corto, senza si rallenta.
    mutating func recordTick(changed: Bool) {
        if changed {
            step = 0
            idleTicksAtMax = 0
        } else if step < Self.steps.count - 1 {
            step += 1
        } else {
            idleTicksAtMax += 1
        }
    }
}
