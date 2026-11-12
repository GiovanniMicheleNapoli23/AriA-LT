//
//  AriaSlugState.swift
//  AriaLite
//
//  Created by Giovanni Michele on 11/11/26.
//
//  Se lo slug scritto è libero: Continua si abilita solo con `.available` per lo slug di adesso.
//

import Foundation

nonisolated enum AriaSlugState: Equatable, Sendable {
    /// Troppo corto per chiedere (meno di 2 caratteri).
    case idle
    /// Si aspetta la fine della scrittura (400 ms) o la risposta.
    case checking
    case available
    case taken
    /// Il server non ha risposto: si riprova scrivendo, o con "Riprova".
    case failed
}
