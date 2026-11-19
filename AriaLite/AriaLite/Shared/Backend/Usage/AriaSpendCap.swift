//
//  AriaSpendCap.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il tetto di spesa: la scheda di GET /v1/usage/spend-cap, lo storico delle modifiche e il body del salvataggio
//  (PUT). Un importo `null` è "nessun tetto", mai 0. Lettura tollerante: un campo illeggibile vale `nil`.
//

import Foundation

/// Di chi è il tetto: del cliente, dell'assistenza AriA o della prova.
nonisolated enum AriaSpendCapSource: String, Sendable, Equatable {
    case tenant, superAdmin = "super_admin", trial
}

/// Cosa sta dietro il tetto mostrato: un tetto salvato (`record`) o quello di partenza del piano (`default`).
nonisolated enum AriaSpendCapOrigin: String, Sendable, Equatable {
    case record, `default`
}

/// Perché l'azienda non può salvare un tetto: la prova (€0) o nessun piano assegnato.
nonisolated enum AriaSpendCapLock: String, Sendable, Equatable {
    case trial, unassigned
}

/// GET /v1/usage/spend-cap. Chi non vede i soldi riceve solo `amount`, `credits_equivalent`, `status` e `can_edit`.
nonisolated struct AriaSpendCapView: Decodable, Sendable, Equatable {
    /// Euro per ciclo; `nil` = nessun tetto.
    var amount: Decimal?
    /// Il tetto in crediti interi al prezzo di un credito extra.
    var creditsEquivalent: Decimal?
    var status: AriaSpendCapStatus?
    /// Chi legge può salvare un tetto. Mancante: `true`, salvo `locked` (sezione 8 del contratto).
    var canEdit = true
    var currency: String?
    /// Da quando vale (UTC, anche senza fuso: `AriaDate`).
    var effectiveFrom: Date?
    var source: AriaSpendCapSource?
    var origin: AriaSpendCapOrigin?
    /// Il valore con cui precompilare il campo quando non c'è un tetto.
    var suggestion: Decimal?
    /// Il tetto più basso che il piano accetta.
    var minimum: Decimal?
    /// La quota del tetto a cui l'azienda viene avvisata (0.80).
    var warnShare: Decimal?
    var locked: AriaSpendCapLock?
    var amountsVisible = false

    private enum CodingKeys: String, CodingKey {
        case amount, status, currency, source, origin, suggestion, minimum, locked
        case creditsEquivalent = "credits_equivalent", canEdit = "can_edit", effectiveFrom = "effective_from"
        case warnShare = "warn_share", amountsVisible = "amounts_visible"
    }

    init() {}

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        amount = c.ariaDecimal(.amount)
        creditsEquivalent = c.ariaDecimal(.creditsEquivalent)
        status = c.ariaLenient(String.self, .status).flatMap(AriaSpendCapStatus.init(rawValue:))
        currency = c.ariaLenient(.currency)
        effectiveFrom = AriaDate.parse(c.ariaLenient(String.self, .effectiveFrom))
        source = c.ariaLenient(String.self, .source).flatMap(AriaSpendCapSource.init(rawValue:))
        origin = c.ariaLenient(String.self, .origin).flatMap(AriaSpendCapOrigin.init(rawValue:))
        suggestion = c.ariaDecimal(.suggestion)
        minimum = c.ariaDecimal(.minimum)
        warnShare = c.ariaDecimal(.warnShare)
        locked = c.ariaLenient(String.self, .locked).flatMap(AriaSpendCapLock.init(rawValue:))
        amountsVisible = c.ariaLenient(.amountsVisible) ?? false
        canEdit = c.ariaLenient(.canEdit) ?? (locked == nil)
    }

    /// La scheda è quella della prova: `locked` è `trial` o la fonte è `trial`.
    var isTrial: Bool { locked == .trial || source == .trial }
}

/// Chi ha salvato un tetto: il ruolo di allora, l'assistenza o la prova.
nonisolated enum AriaSpendCapSetByRole: String, Sendable, Equatable {
    case owner, admin, superAdmin = "super_admin", trial
}

/// Una riga di GET /v1/usage/spend-cap/history (la più recente per prima).
nonisolated struct AriaSpendCapChange: Decodable, Sendable, Equatable {
    var effectiveFrom: Date?
    /// L'id di chi l'ha salvato; `nil` per la prova e per l'assistenza AriA ("AriA support").
    var setBy: String?
    var setByRole: AriaSpendCapSetByRole?
    /// `nil` per il primo tetto o dopo uno tolto.
    var previousAmount: Decimal?
    /// `nil` per una modifica che ha tolto il tetto.
    var amount: Decimal?
    var source: AriaSpendCapSource?

    private enum CodingKeys: String, CodingKey {
        case amount, source
        case effectiveFrom = "effective_from", setBy = "set_by", setByRole = "set_by_role"
        case previousAmount = "previous_amount"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        effectiveFrom = AriaDate.parse(c.ariaLenient(String.self, .effectiveFrom))
        setBy = c.ariaLenient(.setBy)
        setByRole = c.ariaLenient(String.self, .setByRole).flatMap(AriaSpendCapSetByRole.init(rawValue:))
        previousAmount = c.ariaDecimal(.previousAmount)
        amount = c.ariaDecimal(.amount)
        source = c.ariaLenient(String.self, .source).flatMap(AriaSpendCapSource.init(rawValue:))
    }
}

/// Il body di PUT /v1/usage/spend-cap: `{"amount": "500"}` salva, `{"amount": null}` toglie il tetto. L'importo va
/// come stringa col punto e il `null` si scrive sempre (la chiave non si omette mai).
nonisolated struct AriaSpendCapRequest: Encodable, Sendable, Equatable {
    /// `nil` toglie il tetto.
    var amount: Decimal?

    private enum CodingKeys: String, CodingKey { case amount }

    init(amount: Decimal?) {
        self.amount = amount
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let amount {
            try c.encode(AriaDecimal.wire(amount), forKey: .amount)
        } else {
            try c.encodeNil(forKey: .amount)
        }
    }
}
