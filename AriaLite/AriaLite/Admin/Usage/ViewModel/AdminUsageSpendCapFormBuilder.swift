//
//  AdminUsageSpendCapFormBuilder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il campo "Limit per cycle (EUR)" (contratto 5.1): cosa mostra, l'invio (lettura, minimo, conferma se si scende sotto
//  quanto già usato) e la frase "= {credits} credits at {price} per credit". Funzioni pure: lo stato (testo scritto,
//  invio non valido, salvataggio in corso) lo tiene il view model.
//

import Foundation

nonisolated struct AdminUsageSpendCapFormInput: Sendable {
    /// Quello che si è scritto; `nil` finché non si tocca il campo.
    var draft: String?
    /// Si sta modificando un limite in vigore ("Change").
    var editing = false
    /// L'ultimo invio non era valido.
    var invalid = false
    /// Il saldo (e quanto il ciclo ha addebitato): "Save" aspetta che sia letto.
    var allowance: AdminUsagePhase = .idle
    var saving = false
    var saveFailed = false
}

nonisolated enum AdminUsageSpendCapFormBuilder {
    /// Il campo è visibile: senza limite, oppure dopo "Change". Mai nella prova.
    static func isShown(cap: AriaSpendCapView, editing: Bool) -> Bool {
        !cap.isTrial && (cap.amount == nil || editing)
    }

    static func form(_ f: AdminUsageFacts, cap: AriaSpendCapView, input: AdminUsageSpendCapFormInput) -> AdminUsageSpendCapForm {
        let inForce = cap.amount != nil
        let alwaysOn = f.config.spendCapDefaultEur != nil
        let text = input.draft ?? (inForce ? cap.amount.map(AdminUsageSpendCapAmount.fieldText) : cap.suggestion.map(AdminUsageSpendCapAmount.fieldText)) ?? ""
        let minimumText = AdminUsageSpendCapBuilder.money(cap.minimum ?? 0, f, cap)

        // Cosa compra l'importo scritto: solo mentre si cambia un limite in vigore e il campo è valido.
        var preview: String?
        if inForce, input.editing, !input.invalid,
           case .valid(let typed) = AdminUsageSpendCapAmount.check(text, minimum: nil),
           let credits = AdminUsageSpendCapAmount.credits(buying: typed, at: f.config.pricePerCredit),
           let price = AdminUsageSpendCapBuilder.priceText(f, cap) {
            let figure = AdminUsageFormat.whole(credits, locale: f.locale)
            preview = String(localized: "= \(figure) credits") + " " + String(localized: "at \(price) per credit")
        }

        // "Suggested: …" solo senza limite; poi "Set €0 to never pay…" o, con un limite di partenza, "Minimum {amount}.".
        var help: [String] = []
        if !inForce, let suggestion = cap.suggestion {
            let amount = AdminUsageSpendCapBuilder.money(suggestion, f, cap)
            help.append(String(localized: "Suggested: your monthly plan price, \(amount)."))
        }
        if alwaysOn {
            if cap.minimum != nil, !input.invalid { help.append(String(localized: "Minimum \(minimumText).")) }
        } else {
            let zero = AdminUsageSpendCapBuilder.money(0, f, cap)
            help.append(String(localized: "Set \(zero) to never pay for extra credits."))
        }

        return AdminUsageSpendCapForm(
            label: String(localized: "Limit per cycle (EUR)"),
            text: text,
            invalidText: input.invalid ? String(localized: "Enter an amount of \(minimumText) or more.") : nil,
            preview: preview,
            help: help.isEmpty ? nil : help.joined(separator: " "),
            saveTitle: input.saving ? String(localized: "usage.autosave.saving", defaultValue: "Saving…")
                : inForce ? String(localized: "Save") : String(localized: "usage.spendCap.set", defaultValue: "Set limit"),
            // "Save" aspetta il saldo: senza quanto il ciclo ha addebitato non si può controllare se si scende sotto.
            saveEnabled: !input.saving && input.allowance == .loaded && f.capKnown,
            showsCancel: input.editing,
            usedError: input.allowance == .failed
                ? String(localized: "What this cycle has used could not be loaded, so the limit cannot be saved yet.") : nil,
            saveError: input.saveFailed ? String(localized: "The limit was not saved. Try again.") : nil)
    }

    // MARK: Invio

    nonisolated enum Submission: Sendable, Equatable {
        /// Non è un importo, o è sotto il minimo: "Enter an amount of {minimum} or more." e non si manda niente.
        case invalid
        /// Il nuovo limite è sotto quanto il ciclo ha già addebitato: si chiede conferma.
        case confirm(AdminUsageSpendCapConfirmation)
        case save(Decimal)
    }

    static func submit(_ text: String, _ f: AdminUsageFacts, cap: AriaSpendCapView) -> Submission {
        guard case .valid(let amount) = AdminUsageSpendCapAmount.check(text, minimum: cap.minimum) else { return .invalid }
        if let confirmation = confirmation(f, cap: cap, amount: amount) { return .confirm(confirmation) }
        return .save(amount)
    }

    /// "Lower the limit below what's already used?": solo se quanto addebitato è noto e supera il nuovo limite.
    static func confirmation(_ f: AdminUsageFacts, cap: AriaSpendCapView, amount: Decimal) -> AdminUsageSpendCapConfirmation? {
        guard let billed = f.capBilled, billed > amount else { return nil }
        let used = AdminUsageFormat.amount(billed, currency: cap.currency ?? f.currency, locale: f.locale)
        let limit = AdminUsageSpendCapBuilder.money(amount, f, cap)
        let date = f.reset
        let body = f.stop && !cap.isTrial
            ? String(localized: "\(used) of extra credits are already used this cycle, more than the new \(limit) limit. Usage past the included credits stops right away, until \(date).")
            : String(localized: "\(used) of extra credits are already used this cycle, more than the new \(limit) limit. AriA switches to a lighter model right away, until \(date).")
        return AdminUsageSpendCapConfirmation(
            title: String(localized: "Lower the limit below what's already used?"), body: body,
            button: String(localized: "Lower limit"), amount: amount)
    }
}
