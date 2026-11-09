//
//  AriaChatLayoutState.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Decisioni di layout della chat che non dipendono dal backend: quanto spazio ha la chat vuota,
//  quando la lista segue l'ultimo messaggio e cosa occupa il fondo dello schermo.
//

import SwiftUI

/// Come si dispone la chat vuota nello spazio libero (senza barra, composer e tastiera).
/// Con poco spazio la sfera si rimpicciolisce, il saluto perde la prima riga e i suggerimenti
/// passano da griglia a riga scorrevole: niente finisce sotto barra o composer.
enum AriaChatEmptyLayout: Equatable {
    /// Sfera grande, saluto completo, suggerimenti in griglia 2×2.
    case regular
    /// Sfera piccola, solo la domanda del saluto, suggerimenti in riga scorrevole.
    case compact
    /// Schermi molto bassi con la tastiera aperta: restano solo la sfera e i suggerimenti.
    case minimal
    /// iPhone in orizzontale con la tastiera aperta: solo la riga dei suggerimenti.
    case suggestionsOnly
    /// Neanche la riga ci sta (meno di una card): la chat vuota resta vuota finché si scrive.
    case hidden

    init(height: CGFloat, hasSuggestions: Bool) {
        // Sotto queste altezze la chat vuota non ci sta intera.
        if !hasSuggestions {
            self = height < 320 ? .compact : .regular
        } else if height < 120 {
            self = .hidden
        } else if height < 200 {
            self = .suggestionsOnly
        } else if height < 270 {
            self = .minimal
        } else {
            self = height < 540 ? .compact : .regular
        }
    }

    var isCompact: Bool { self != .regular }
    var showsGreeting: Bool { self == .regular || self == .compact }
    var showsOrb: Bool { self != .suggestionsOnly && self != .hidden }
    var showsSuggestions: Bool { self != .hidden }
}

/// La chat segue l'ultimo messaggio. Smette solo quando è l'operatore a scorrere verso l'alto:
/// il testo che cresce durante lo streaming non deve mai fargli perdere il "segui".
struct AriaChatScrollFollow: Equatable {
    /// Altezza del contenuto e della finestra visibile: se cambia una delle due e si sta seguendo, si torna in fondo.
    struct Sizes: Equatable {
        var content: CGFloat
        var container: CGFloat
    }

    private(set) var followsBottom = true
    var isNearBottom = true
    /// Scorrimento fatto con il dito (non da `scrollTo`).
    private(set) var isUserScrolling = false
    /// Si scrive in un campo dentro un messaggio (ricordo, parametri da approvare): la tastiera che si apre
    /// non deve trascinare la lista in fondo, con il campo fuori schermo.
    var isEditingInline = false

    /// Il pulsante per tornare in fondo: solo se l'operatore si è allontanato.
    var showsJumpToBottom: Bool { !followsBottom && !isNearBottom }

    /// Solo il dito decide se seguire: finito lo scorrimento, si segue se si è rimasti in fondo.
    mutating func phaseChanged(to phase: ScrollPhase) {
        switch phase {
        case .tracking, .interacting:
            isUserScrolling = true
        case .idle:
            if isUserScrolling { followsBottom = isNearBottom }
            isUserScrolling = false
        default:
            break
        }
    }

    /// Solo se c'è davvero da scorrere: con un contenuto più corto dello schermo non serve.
    func sticksToBottom(_ sizes: Sizes) -> Bool {
        followsBottom && !isUserScrolling && !isEditingInline && sizes.content > sizes.container + 1
    }

    /// Un messaggio nuovo o il pulsante "torna in fondo": si riprende a seguire.
    mutating func followBottom() {
        followsBottom = true
    }
}

/// Cosa c'è in fondo: la procedura, la domanda guidata o il composer. I dati viaggiano con il caso,
/// così il pannello che esce si disegna ancora mentre la chat è già passata oltre.
enum AriaChatBottomPanel: Equatable {
    case composer
    case question(AriaElicitation)
    case procedure(messageId: String, list: AriaTaskList)
    case learning(messageId: String, request: AriaValidationRequest)
    case learned(AriaLearningOutcome)
}
