//
//  AriaSetupTourAccess.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Cosa può fare chi guarda, come lo decidono le schermate (come `GuideAccess` della web): le sezioni che la
//  sidebar offre e i permessi per le azioni che i passi indicano. Da qui si ricavano i passi: uno c'è solo se la
//  sua sezione è offerta e l'utente può fare la cosa indicata. Sono solo Bool, così si prova senza il backend.
//

import Foundation

nonisolated struct AriaSetupTourAccess: Equatable, Sendable {
    /// Le sezioni che la sidebar offre ora.
    var offered: Set<AriaDestination> = []
    /// C'è almeno un sito dove caricare i documenti: senza, il passo del caricamento usa il testo `noPlant`.
    var hasSite = true
    /// Owner o admin: Governance (policy).
    var canGovern = false
    /// Owner o admin: "New person" (`AdminMemberRules.canCreate`).
    var canInvite = false
    /// Teams · create.
    var canCreateTeam = false
    /// Owner o admin: i connettori del Marketplace.
    var canConnect = false

    /// Il passo c'è per questo utente? Le stesse regole delle schermate. Caricamento, revisione, agenti e
    /// workflow non hanno un diritto proprio nell'app: bastano le sezioni offerte.
    func allows(_ step: AriaSetupTourStep) -> Bool {
        guard offered.contains(step.destination) else { return false }
        switch step {
        case .upload, .extraction, .agents, .workflows: return true
        case .governance: return canGovern
        case .invite: return canInvite
        case .teams: return canCreateTeam
        case .connectors: return canConnect
        }
    }

    /// I passi di questo utente, nell'ordine fisso del giro.
    var steps: [AriaSetupTourStep] {
        AriaSetupTourStep.allCases.filter(allows)
    }

    /// Le sezioni della guida che hanno almeno un passo, nell'ordine in cui si presentano.
    var sections: [AriaSetupTourSection] {
        let taken = Set(steps.map(\.section))
        return AriaSetupTourSection.allCases.filter(taken.contains)
    }
}
