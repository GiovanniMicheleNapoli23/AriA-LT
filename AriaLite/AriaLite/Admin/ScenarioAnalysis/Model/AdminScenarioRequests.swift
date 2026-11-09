//
//  AdminScenarioRequests.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I body delle scritture della sezione (correzione del verdetto, nota dell'admin) e la risposta
//  di un giro di backfill degli scenari.
//

import Foundation

/// POST …/session-reviews/{session_id}: il verdetto corretto. `outcome` conta (rifà i conteggi),
/// voto e problemi descrivono la qualità. I nil non si mandano.
nonisolated struct AdminScenarioReviewRequest: Encodable, Sendable {
    let outcome: String
    let rating: Int?
    let issues: String?
}

/// POST …/session-reviews/{session_id}/note: si aggiunge, non si modifica mai.
nonisolated struct AdminScenarioNoteRequest: Encodable, Sendable {
    let note: String
}

/// Un lotto di POST …/scenarios/backfill. Si richiama finché `hasMore` è vero.
nonisolated struct AdminScenarioBackfillResult: Decodable, Sendable {
    let processed: Int?
    let recorded: Int?
    let skipped: Int?
    let optedOut: Int?
    let hasMore: Bool?
}
