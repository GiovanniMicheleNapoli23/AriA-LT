//
//  AriaHelpChatSlot.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La chat di "Ask AriA" di un passo, condivisa tra il chiamante e il foglio.
//

import Observation

/// La chat di "Ask AriA" di un'esecuzione: la tiene il chiamante, il foglio la legge da qui.
/// Un oggetto osservabile e non un `@State` opzionale: il contenuto di `.sheet(isPresented:)` può essere
/// costruito con il valore di prima del tocco che lo apre (era nil → foglio vuoto); questo invece è
/// sempre lo stesso oggetto e la chat si legge quando il foglio si disegna.
@Observable
final class AriaHelpChatSlot {
    var chat: AriaAgentChat?
}
