//
//  AdminCraftedItem.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Una riga della libreria Crafted: o il rapporto di una procedura conclusa (da session-reviews) o
//  una cosa che Aria ha fatto su richiesta (dallo store). Dà a entrambe titolo, data e categoria.
//

import Foundation

nonisolated enum AdminCraftedItem: Identifiable, Hashable, Sendable {
    case report(AdminCraftedSessionReview)
    case artifact(AdminCraftedArtifact)

    /// `report:<sessione>:<episodio>` / `art:<id>`.
    var id: String {
        switch self {
        case .report(let review): "report:\(review.sessionId):\(review.episode ?? 1)"
        case .artifact(let artifact): "art:\(artifact.id)"
        }
    }

    var title: String {
        switch self {
        case .report(let review): review.displayTitle
        case .artifact(let artifact): artifact.title
        }
    }

    /// Rapporto: la data dell'intervento (`startedAt`, altrimenti l'ultima modifica; come la web). Artifact: quando è stato creato.
    var date: Date? {
        switch self {
        case .report(let review): AriaDate.parse(review.startedAt ?? review.updatedAt)
        case .artifact(let artifact): artifact.createdAt
        }
    }

    /// La data per ordinare: senza data in fondo.
    var sortDate: Date { date ?? .distantPast }

    /// Il tipo da mostrare: `report`, o quello della prima card; `document` se Aria ha risposto a parole.
    var kind: String {
        switch self {
        case .report: "report"
        case .artifact(let artifact): artifact.artifacts.first?.kind ?? "document"
        }
    }

    /// Dove si archivia: un rapporto è un documento; un artifact è il tipo della sua prima card, quando ce l'ha.
    var category: AdminCraftedCategory {
        switch self {
        case .report:
            return .documents
        case .artifact(let artifact):
            if artifact.status == .generating { return .pending }
            if let first = artifact.artifacts.first { return .of(kind: first.kind) }
            return artifact.status == .ready ? .documents : .pending
        }
    }

    var sessionId: String {
        switch self {
        case .report(let review): review.sessionId
        case .artifact(let artifact): artifact.sessionId
        }
    }
}
