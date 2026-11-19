//
//  AriaTrialOffer+Content.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Le cifre, le righe incluse e gli altri piani della card della demo gratuita, nell'ordine e con le regole della web.
//

import Foundation

nonisolated extension AriaTrialOffer {
    /// Utenti, crediti AI al giorno e GB di knowledge base: i crediti solo se il listino li dice, i GB solo se noti.
    static func makeFigures(_ trial: AriaPublicTrial?, locale: Locale) -> [Figure] {
        guard let trial else { return [] }
        let users = trial.userCap == 1 ? String(localized: "user") : String(localized: "users")
        var figures = [Figure(value: number(trial.userCap, locale: locale), label: users)]
        if let credits = trial.creditsPerDay {
            figures.append(Figure(value: number(credits, locale: locale), label: String(localized: "AI credits every day")))
        }
        if let gb = trial.kbCapacityGb {
            figures.append(Figure(value: gigabytes(gb, locale: locale), label: String(localized: "GB knowledge base")))
        }
        return figures
    }

    /// Con la prova: operatori mobile e attività parallele del piano, le quattro claim, la knowledge base oltre il
    /// limite e, solo con il tetto di spesa a 0, "mai addebitati" e "modello più leggero". Senza prova: le righe di
    /// sempre (nessuna mentre il listino arriva).
    static func makeLines(state: AriaPriceListState, list: AriaPublicPriceList?, trial: AriaPublicTrial?,
                      locale: Locale) -> [String] {
        guard let trial else { return state == .loading ? [] : legacyLines }
        var lines: [String] = []
        let tier = list?.tier(trial.tier)
        if let operators = tier?.mobileOperatorsIncluded {
            lines.append(String(localized: "Mobile app for \(operators) operators"))
        }
        if let tasks = tier?.maxParallelTasks {
            lines.append(String(localized: "\(tasks) parallel agent tasks"))
        }
        lines += claims
        if let gb = trial.kbCapacityGb {
            lines.append(String(localized: "Past the \(gigabytes(gb, locale: locale)) GB knowledge base, uploads continue and the owner is notified"))
        }
        if trial.overageSpendCapEur == 0 {
            lines.append(String(localized: "Extra credits are never billed during the trial"))
            lines.append(String(localized: "Past the included credits, answers continue on a lighter model."))
        }
        return lines
    }

    /// Le quattro claim senza numeri della prova.
    private static var claims: [String] {
        [String(localized: "Single · Vertical RAG"), String(localized: "Limited Work Orders"),
         String(localized: "Limited compliance"), String(localized: "Community support")]
    }

    /// Le righe della demo prima del listino (`auth.login.plans.legacy.free_demo` della web).
    private static var legacyLines: [String] {
        [String(localized: "Pre-registered · 1 user"), String(localized: "1 demo agent family"),
         String(localized: "1GB document memory"), String(localized: "Single - Vertical RAG"),
         String(localized: "Limited Work Orders"), String(localized: "Limited compliance"),
         String(localized: "Community support")]
    }

    /// Basic, Basic Plus e Professional "in arrivo"; Enterprise ed Enterprise AR+ scrivono alle vendite.
    static func makeOtherPlans(salesEmail: String?) -> [PlanRow] {
        let trimmed = salesEmail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let email = trimmed.isEmpty ? defaultSalesEmail : trimmed
        let mailto = URL(string: "mailto:\(email)") ?? URL(string: "mailto:\(defaultSalesEmail)")!
        return [
            PlanRow(id: "basic", name: tierName("basic"), tagline: String(localized: "Ideal for single-site tasks."), kind: .soon),
            PlanRow(id: "basic_plus", name: tierName("basic_plus"),
                    tagline: String(localized: "Built for small to mid-size sites."), kind: .soon),
            PlanRow(id: "professional", name: tierName("professional"),
                    tagline: String(localized: "Suitable for most teams."), kind: .soon),
            PlanRow(id: "enterprise", name: tierName("enterprise"),
                    tagline: String(localized: "Designed for large-scale needs."), kind: .contact(mailto)),
            PlanRow(id: "enterprise_ar_plus", name: tierName("enterprise_ar_plus"),
                    tagline: String(localized: "AI in the operator’s field of view."), kind: .contact(mailto)),
        ]
    }
}
