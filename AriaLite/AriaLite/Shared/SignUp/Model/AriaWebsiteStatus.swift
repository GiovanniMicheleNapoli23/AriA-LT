//
//  AriaWebsiteStatus.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  A che punto è il controllo del sito web aziendale nel passo Azienda: vuoto, in corso, verificato, o il problema
//  trovato (formato, provider di posta, dominio che non esiste, DNS che non ha risposto).
//

import Foundation

nonisolated enum AriaWebsiteStatus: Equatable, Sendable {
    case idle
    case checking
    case verified
    case problem(AriaWebsiteProblem)

    init(_ check: AriaWebsiteCheck) {
        switch check {
        case .ok: self = .verified
        case .problem(let problem): self = .problem(problem)
        }
    }

    /// Il pulsante può andare avanti: verificato, o non verificabile ora (il salvataggio ricontrolla).
    var allowsContinuing: Bool {
        switch self {
        case .verified: true
        case .problem(let problem): !problem.blocksSaving
        case .idle, .checking: false
        }
    }

    var problem: AriaWebsiteProblem? {
        if case .problem(let problem) = self { return problem }
        return nil
    }
}
