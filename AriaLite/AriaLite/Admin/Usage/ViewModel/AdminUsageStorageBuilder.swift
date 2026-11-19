//
//  AdminUsageStorageBuilder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda "Knowledge storage" (contratto 3.8, `lib/usage/storage.ts` e `storage-indicator.tsx` della web). I byte,
//  lo stato (`ok`, `warning`, `over_cap`, `unlimited`) e il prezzo del componente aggiuntivo vengono dal server:
//  l'app sceglie solo le parole, in base al piano (add-on fatturato, prova, contratto, nessun piano) e a chi legge.
//

import Foundation

nonisolated enum AdminUsageStorageBuilder {
    /// Quale frase del piano si legge: la prima che vale (nessun piano, prova, contratto, altrimenti add-on fatturato).
    nonisolated enum Wording: Sendable, Equatable {
        case bill, trial, contract, fallback
    }

    static func wording(_ storage: AriaUsageStorage) -> Wording {
        if storage.tierSource != "assignment" { return .fallback }
        if storage.planKind == .trial { return .trial }
        if storage.mode == .allowAndNotify { return .contract }
        return .bill
    }

    static func state(_ f: AdminUsageFacts, allowance: AriaAllowance?, phase: AdminUsagePhase) -> AdminUsageStorageState {
        guard let allowance else { return phase == .failed ? .failed : .loading }
        guard let storage = allowance.storage, let ready = card(f, storage) else { return .failed }
        return .ready(ready)
    }

    /// `nil` quando i byte usati non si leggono: niente cifra inventata.
    static func card(_ f: AdminUsageFacts, _ storage: AriaUsageStorage) -> AdminUsageStorageCard? {
        guard let used = storage.usedBytes else { return nil }
        let locale = f.locale
        let included: Int? = storage.state != .unlimited && (storage.includedBytes ?? 0) > 0 ? storage.includedBytes : nil
        let plan = wording(storage)
        let owner = f.owner
        let price = owner && plan == .bill ? storage.pricePerGbMonth : nil

        // Oltre la capacità vuol dire strettamente più di essa: a capacità esatta il server dice `over_cap` ma non c'è un
        // eccesso, si legge "pieno" con 0 rimasti.
        let over = included.map { max(0, used - $0) } ?? 0
        let tone: AdminUsageTone
        if included == nil {
            tone = .normal
        } else if over > 0 {
            tone = .over
        } else {
            tone = storage.state == .warning || storage.state == .overCap ? .warning : .normal
        }

        let usedText = AdminUsageFormat.gigabytes(used, locale: locale)
        let total = AdminUsageFormat.gigabytes(included ?? 0, locale: locale)
        let left = AdminUsageFormat.gigabytes(max(0, (included ?? 0) - used), rounding: .down, locale: locale)
        let overText = AdminUsageFormat.gigabytes(over, rounding: .up, locale: locale)

        var result = AdminUsageStorageCard(
            title: String(localized: "usage.storage.title", defaultValue: "Knowledge storage"),
            used: usedText,
            ofText: included == nil ? String(localized: "usage.storage.used", defaultValue: "used") : String(localized: "of \(total)"),
            asOfToday: f.closed ? String(localized: "Uploaded files, as of today") : nil,
            hasCapacity: included != nil, fillFraction: 0, overFraction: 0, tone: tone)

        if let included {
            let ratio = Decimal(used) / Decimal(included)
            result.fillFraction = over > 0 ? Double(included) / Double(used) : min(1, NSDecimalNumber(decimal: ratio).doubleValue)
            result.overFraction = over > 0 ? Double(over) / Double(used) : 0
            // La quota è del server; senza, la si ricava dai byte solo per scrivere la percentuale.
            let pct = AdminUsageFormat.whole(AdminUsageFormat.percent(storage.share ?? ratio), locale: locale)
            result.percentText = String(localized: "\(pct)% used")
            result.leftText = over > 0
                ? String(localized: "\(overText) over")
                : (used == 0 ? String(localized: "Nothing uploaded yet") : String(localized: "\(left) left"))
        } else if owner {
            result.contractNote = String(localized: "Your storage is set in your contract.")
        }
        if let addon = storage.addonBytes, addon > 0 {
            let amount = AdminUsageFormat.gigabytes(addon, locale: locale)
            result.addonText = String(localized: "Includes \(amount) of added storage")
        }
        if tone != .normal {
            result.badge = tone == .over ? String(localized: "Over limit") : String(localized: "Almost full")
            // Un titolare il cui add-on fatturato non ha prezzo (il server l'ha tenuto) legge le parole del membro:
            // non fanno promesse su un prezzo.
            let asOwner = owner && !(plan == .bill && price == nil)
            let priceText = price.map { f.money($0) } ?? ""
            result.notice = notice(tone: tone, wording: plan, asOwner: asOwner, left: left, total: total,
                                 over: overText, price: priceText)
        }
        result.action = action(f, wording: plan, price: price)
        return result
    }

    // MARK: Azione

    /// L'unica azione di vendita: add-on a pagamento (con il prezzo del server), prova ("Choose a plan"), contratto
    /// ("Contact sales"). Solo un titolare, e c'è un indirizzo. Senza piano non ce n'è.
    static func action(_ f: AdminUsageFacts, wording: Wording, price: Decimal?) -> AdminUsageMailAction? {
        guard f.owner, let email = f.email else { return nil }
        switch wording {
        case .bill:
            guard let price else { return nil }
            let amount = f.money(price)
            let label = String(localized: "Add storage · \(amount) / GB / month")
            return AdminUsageMail.action(label: label, subject: label, email: email)
        case .trial:
            let label = String(localized: "Choose a plan")
            return AdminUsageMail.action(label: label, subject: label, email: email)
        case .contract:
            let label = String(localized: "Contact sales")
            guard let key = f.config.plan?.tier, !key.isEmpty else {
                return AdminUsageMail.action(label: label, subject: label, email: email)
            }
            let currentPlan = AdminUsageWords.planName(key)
            return AdminUsageMail.action(label: label, subject: String(localized: "\(currentPlan) plan: contact sales"), email: email)
        case .fallback:
            return nil
        }
    }
}
