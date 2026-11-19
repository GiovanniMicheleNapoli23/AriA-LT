//
//  AdminUsageNoticeFold.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il salvataggio delle regole degli avvisi sostituisce tutto: ogni body deve contenere tutto quello che l'azienda
//  tiene come suo. `payload(applying:to:)` parte da una vista, quindi la vista deve già contenere le modifiche precedenti
//  anche se la loro risposta non è ancora arrivata. Qui si "ripiega" un body sulla vista: `company` diventa quello del
//  body e `resolved` quello dell'azienda se c'è, altrimenti quello della piattaforma.
//

import Foundation

nonisolated extension AriaNoticeField {
    /// Lo stesso campo con il valore dell'azienda dato (`nil` segue la piattaforma) e `resolved` di conseguenza.
    func adopting(_ company: Value?) -> AriaNoticeField<Value> {
        AriaNoticeField(platform: platform, company: company, resolved: company ?? platform)
    }
}

nonisolated extension AriaNoticeRule {
    func adopting(_ override: AriaNoticeOverride) -> AriaNoticeRule {
        var rule = self
        rule.email = email.adopting(override.email)
        rule.banner = banner.adopting(override.banner)
        rule.threshold = threshold.adopting(override.threshold)
        rule.repeatPolicy = repeatPolicy.adopting(override.repeatPolicy)
        rule.tenantRecipients = tenantRecipients.adopting(override.tenantRecipients)
        rule.userIds = userIds.adopting(override.userIds)
        return rule
    }
}

nonisolated extension AriaNoticeSettings {
    /// La vista come sarà quando il server avrà accettato `body` (un body costruito da `payload(applying:to:)`).
    /// Vale: `adopting(body).companyOverrides == body`.
    func adopting(_ body: AriaNoticeOverrides) -> AriaNoticeSettings {
        var view = self
        view.dailyAllowance = dailyAllowance.adopting(body[.dailyAllowance])
        view.capApproaching = capApproaching.adopting(body[.capApproaching])
        view.overage = overage.adopting(body[.overage])
        return view
    }
}
