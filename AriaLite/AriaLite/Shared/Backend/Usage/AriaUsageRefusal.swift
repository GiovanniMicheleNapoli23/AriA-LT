//
//  AriaUsageRefusal.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  I rifiuti delle rotte del tetto di spesa e degli avvisi (sezione 7 del contratto). `detail` è una stringa semplice
//  (503, 422 del cruscotto) oppure un oggetto con `code` e, a seconda del codice, `minimum`, `user_ids`, `notice`,
//  `expected`. Il codice si legge solo quando `detail` è un oggetto, mai il testo del server. `AriaHTTP.check` li
//  trasforma in `AriaError.usageRefused`, come per i rifiuti delle persone.
//

import Foundation

/// Il corpo di un errore delle rotte d'uso: `detail` in tutte e due le forme. Non fallisce mai.
nonisolated struct AriaUsageErrorBody: Sendable, Equatable {
    /// `detail` quando è una stringa, oppure `detail.message` quando è un oggetto che lo ha.
    var text: String?
    /// `detail.code`, solo quando `detail` è un oggetto.
    var code: String?
    /// `detail.minimum` (`spend_cap_below_minimum`): il tetto più basso del piano.
    var minimum: Decimal?
    /// `detail.user_ids` (`recipient_not_active_member`): le persone che non sono più membri attivi.
    var userIds: [String] = []
    /// `detail.notice` (`notice_threshold_out_of_range`): `daily_allowance`, `cap_approaching` o `overage`.
    var notice: AriaNoticeKey?
    /// `detail.expected` (`notice_threshold_out_of_range`): l'intervallo atteso, come lo scrive il server ("(0, 1]").
    var expected: String?

    init(data: Data) {
        guard let detail = (try? JSONDecoder().decode(AriaJSON.self, from: data))?["detail"] else { return }
        switch detail {
        case .string(let text):
            self.text = text
        case .object(let fields):
            code = fields["code"]?.stringValue
            text = fields["message"]?.stringValue
            minimum = AriaDecimal.from(fields["minimum"])
            userIds = fields["user_ids"]?.arrayValue.compactMap { item -> String? in
                // Solo gli id scritti come stringa: un numero non è un id.
                if case .string(let id) = item { id } else { nil }
            } ?? []
            notice = fields["notice"]?.stringValue.flatMap(AriaNoticeKey.init(rawValue:))
            expected = fields["expected"]?.stringValue
        default:
            break
        }
    }
}

/// Un rifiuto con un codice noto di PUT /v1/usage/spend-cap, notice-recipients o notice-settings.
nonisolated struct AriaUsageRefusal: Sendable, Equatable {
    enum Code: String, Sendable, CaseIterable {
        /// 409: l'azienda è in prova.
        case spendCapLockedTrial = "spend_cap_locked_trial"
        /// 409: nessun piano assegnato.
        case spendCapLockedUnassigned = "spend_cap_locked_unassigned"
        /// 422: `null` dove il piano tiene il tetto sempre attivo.
        case spendCapRequired = "spend_cap_required"
        /// 422: sotto il minimo del piano (`minimum`).
        case spendCapBelowMinimum = "spend_cap_below_minimum"
        /// 422: una persona scelta non è più un membro attivo (`userIds`). Non si salva niente.
        case recipientNotActiveMember = "recipient_not_active_member"
        /// 422: una soglia fuori intervallo (`notice`, `expected`).
        case noticeThresholdOutOfRange = "notice_threshold_out_of_range"
    }

    let code: Code
    var minimum: Decimal?
    var userIds: [String] = []
    var notice: AriaNoticeKey?
    var expected: String?

    init(code: Code, minimum: Decimal? = nil, userIds: [String] = [], notice: AriaNoticeKey? = nil, expected: String? = nil) {
        self.code = code
        self.minimum = minimum
        self.userIds = userIds
        self.notice = notice
        self.expected = expected
    }

    /// `nil` se `detail` non è un oggetto o il codice non è uno di questi.
    init?(_ data: Data) {
        let body = AriaUsageErrorBody(data: data)
        guard let code = body.code.flatMap(Code.init(rawValue:)) else { return nil }
        self.init(code: code, minimum: body.minimum, userIds: body.userIds, notice: body.notice, expected: body.expected)
    }

    /// Le parole della web: "The limit was not saved. Try again." per tutti e quattro i rifiuti del tetto.
    var message: String {
        switch code {
        case .spendCapLockedTrial, .spendCapLockedUnassigned, .spendCapRequired, .spendCapBelowMinimum:
            String(localized: "The limit was not saved. Try again.")
        case .recipientNotActiveMember:
            String(localized: "Someone you chose is no longer an active member. Remove them to save again.")
        case .noticeThresholdOutOfRange:
            String(localized: "The settings were not saved. Try again.")
        }
    }
}
