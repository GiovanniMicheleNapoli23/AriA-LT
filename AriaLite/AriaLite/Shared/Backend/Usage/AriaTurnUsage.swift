//
//  AriaTurnUsage.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  L'evento `aria.turn_usage` di una risposta (dallo stream o dalla `pipeline` salvata del messaggio): crediti
//  addebitati, stato, livello di impegno a cui è girata. I crediti sono la cifra del server, mai ricalcolata.
//  Un evento illeggibile si scarta: nessuna nota.
//

import Foundation

nonisolated struct AriaTurnUsage: Sendable, Equatable {
    nonisolated enum Status: String, Sendable, Equatable {
        case charged
        case notCharged = "not_charged"
    }

    nonisolated enum ActionStatus: String, Sendable, Equatable {
        case completed, failed, cancelled
    }

    /// A che livello è girata la risposta e perché.
    nonisolated struct Effort: Sendable, Equatable {
        var requested: AriaEffortLevel
        var effective: AriaEffortLevel
        var degraded: Bool
        var multiplier: Decimal?
        /// "tier", "spend_cap", "not_applied" o altro: la frase sotto la risposta cambia solo per i primi due.
        var reason: String?
    }

    /// Può essere `rag.diagnostic` per un normale messaggio di chat.
    var actionType: String?
    var status: Status
    /// `nil` quando il server non lo manda: vale come completata.
    var actionStatus: ActionStatus?
    var credits: Decimal
    /// Ha usato crediti extra.
    var overage: Bool
    /// La risposta si è fermata (carta di approvazione) ed è ripresa: crediti 0 e `not_charged`, già addebitata alla pausa.
    var continuation: Bool
    /// Il tetto di spesa l'ha spostata sul modello più leggero.
    var degradedModel: Bool
    var effort: Effort?
}

nonisolated extension AriaTurnUsage {
    /// `nil` quando l'evento non si legge: crediti non decimali o negativi, stato o `action_status` sconosciuti, il
    /// blocco `effort` mancante o con un livello che l'app non sa nominare. `effort.requested` mancante vale `effective`.
    nonisolated init?(json: AriaJSON) {
        guard case .object = json,
              let credits = AriaDecimal.from(json["credits"]), credits >= 0,
              case .string(let rawStatus)? = json["status"], let status = Status(rawValue: rawStatus) else { return nil }

        var actionStatus: ActionStatus?
        switch json["action_status"] {
        case nil, .null?: break
        case .string(let raw)?:
            guard let known = ActionStatus(rawValue: raw) else { return nil }
            actionStatus = known
        default: return nil
        }

        // Come turnUsageOf della web: senza il blocco `effort` l'evento è illeggibile.
        guard case .object? = json["effort"], let block = json["effort"],
              case .string(let rawEffective)? = block["effective"],
              let effective = AriaEffortLevel(rawValue: rawEffective) else { return nil }
        var requested = effective
        if case .string(let raw)? = block["requested"], let level = AriaEffortLevel(rawValue: raw) { requested = level }
        var reason: String?
        if case .string(let raw)? = block["reason"] { reason = raw }
        let effort = Effort(requested: requested, effective: effective, degraded: Self.flag(block["degraded"]),
                            multiplier: AriaDecimal.from(block["multiplier"]), reason: reason)

        var actionType: String?
        if case .string(let raw)? = json["action_type"] { actionType = raw }
        self.init(actionType: actionType, status: status, actionStatus: actionStatus, credits: credits,
                  overage: Self.flag(json["overage"]), continuation: Self.flag(json["continuation"]),
                  degradedModel: Self.flag(json["degraded_model"]), effort: effort)
    }

    private nonisolated static func flag(_ json: AriaJSON?) -> Bool {
        if case .bool(true)? = json { return true }
        return false
    }

    /// Un evento che arriva dopo un altro della stessa risposta. Una ripresa (`continuation`) tiene crediti, stato e
    /// `overage` dell'evento precedente e prende il resto dal nuovo; senza un evento precedente non dice niente (`nil`:
    /// nessuna nota). Un evento che non è una ripresa sostituisce il precedente.
    nonisolated static func merged(_ earlier: AriaTurnUsage?, with next: AriaTurnUsage) -> AriaTurnUsage? {
        guard next.continuation else { return next }
        guard let earlier else { return nil }
        var merged = next
        merged.status = earlier.status
        merged.actionStatus = earlier.actionStatus
        merged.credits = earlier.credits
        merged.overage = earlier.overage
        merged.continuation = false
        return merged
    }

    /// Gli eventi di una risposta, nell'ordine in cui sono arrivati, ridotti a uno.
    nonisolated static func folded(_ events: [AriaTurnUsage]) -> AriaTurnUsage? {
        events.reduce(nil) { merged($0, with: $1) }
    }
}
