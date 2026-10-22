//
//  AdminScenarioDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di uno scenario: affidabilità e previsione, esiti, fatti imparati usati e l'ultima sessione
//  (con il suo report). Riassunto, descrizione e fatti si traducono nella lingua dell'app; l'originale resta a un tocco.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminScenarioDetailViewModel {
    let backend: AriaBackend
    let scenario: AdminScenario
    /// Il report dell'ultima sessione, se lo scenario ne ha una.
    let lastReport: AdminScenarioReportViewModel?

    /// Chiave → testo tradotto; una chiave che manca si mostra in originale.
    private(set) var translations: [String: String] = [:]
    private(set) var isTranslating = false
    var showsOriginal = false
    @ObservationIgnored private var hasRequestedTranslations = false

    init(backend: AriaBackend, scenario: AdminScenario) {
        self.backend = backend
        self.scenario = scenario
        lastReport = scenario.lastSessionId.map {
            AdminScenarioReportViewModel(backend: backend, sessionId: $0, episode: scenario.lastEpisode ?? 1,
                                         title: scenario.title)
        }
    }

    // MARK: Testi

    private static let summaryKey = "scenario.summary"
    private static let descriptionKey = "scenario.description"
    private static func factKey(_ fact: AdminScenarioFact) -> String { "fact.\(fact.factId)" }

    private func text(_ original: String?, key: String) -> String? {
        guard let original, !original.isEmpty else { return nil }
        guard !showsOriginal else { return original }
        return translations[key] ?? original
    }

    var summary: String? { text(scenario.summary, key: Self.summaryKey) }
    var descriptionText: String? {
        // Spesso la descrizione ripete il riassunto: una volta basta.
        guard scenario.description != scenario.summary else { return nil }
        return text(scenario.description, key: Self.descriptionKey)
    }
    func content(of fact: AdminScenarioFact) -> String { text(fact.content, key: Self.factKey(fact)) ?? fact.content }

    var hasTranslations: Bool { !translations.isEmpty }

    /// Chiede le traduzioni una volta per dettaglio. Se non arrivano si resta sull'originale, senza errori.
    func translate() async {
        guard !hasRequestedTranslations, let companyId = backend.activeCompanyId else { return }
        hasRequestedTranslations = true
        var texts: [String: String] = [:]
        if let summary = scenario.summary { texts[Self.summaryKey] = summary }
        if let description = scenario.description, description != scenario.summary { texts[Self.descriptionKey] = description }
        for fact in scenario.facts { texts[Self.factKey(fact)] = fact.content }
        guard !texts.isEmpty else { return }
        isTranslating = true
        defer { isTranslating = false }
        let api = AriaChatAPI(api: backend.api)
        let locale = backend.api.context.locale
        translations = (try? await api.translateFacts(companyId: companyId, locale: locale, texts)) ?? [:]
    }

    // MARK: Cifre

    var kindLabel: String? {
        scenario.kind.map { AdminScenarioKind(rawValue: $0)?.label ?? AdminScenarioLabel.humanized($0) }
    }

    /// Affidabilità storica, previsione e tempi.
    var reliabilityStats: [AdminScenarioStat] {
        let m = scenario.metrics
        var forecast = AdminScenarioFormat.percent(m?.forecastSuccessRate)
        if m?.forecastLow != nil || m?.forecastHigh != nil {
            let range = "\(AdminScenarioFormat.percent(m?.forecastLow))–\(AdminScenarioFormat.percent(m?.forecastHigh))"
            forecast += " (\(range))"
        }
        return [
            AdminScenarioStat(title: String(localized: "Reliability"), value: AdminScenarioFormat.percent(m?.reliability),
                              systemImage: "checkmark.seal", tone: .positive),
            AdminScenarioStat(title: String(localized: "Next-time forecast"), value: forecast,
                              systemImage: "chart.line.uptrend.xyaxis"),
            AdminScenarioStat(title: String(localized: "Accuracy"), value: AdminScenarioFormat.percent(m?.accuracy),
                              systemImage: "scope"),
            AdminScenarioStat(title: String(localized: "Average steps"), value: AdminScenarioFormat.number(m?.avgSteps),
                              systemImage: "list.number"),
            AdminScenarioStat(title: String(localized: "Average repair time"), value: AdminScenarioFormat.minutes(m?.mttrAvgMin),
                              systemImage: "timer"),
            AdminScenarioStat(title: String(localized: "Expected repair time"), value: AdminScenarioFormat.minutes(m?.mttrExpectedMin),
                              systemImage: "hourglass"),
        ]
    }

    /// Come sono finite le sessioni dello scenario.
    var outcomeStats: [AdminScenarioStat] {
        [
            AdminScenarioStat(title: String(localized: "Sessions"), value: AdminScenarioFormat.count(scenario.supportCount),
                              systemImage: "bubble.left.and.text.bubble.right"),
            AdminScenarioStat(title: String(localized: "Resolved sessions"), value: AdminScenarioFormat.count(scenario.successCount),
                              systemImage: "checkmark.circle", tone: .positive),
            AdminScenarioStat(title: String(localized: "Unresolved sessions"), value: AdminScenarioFormat.count(scenario.failureCount),
                              systemImage: "xmark.circle", tone: .negative),
            AdminScenarioStat(title: String(localized: "Unclear sessions"), value: AdminScenarioFormat.count(scenario.unclearCount),
                              systemImage: "questionmark.circle", tone: .neutral),
            AdminScenarioStat(title: String(localized: "Forced closures"), value: AdminScenarioFormat.count(scenario.forcedClosureCount),
                              systemImage: "stop.circle", tone: .warning),
            AdminScenarioStat(title: String(localized: "Fixed at first try"), value: AdminScenarioFormat.count(scenario.firstShotCount),
                              systemImage: "bolt", tone: .positive),
        ]
    }

    /// Quanto è stato rivisto da persone.
    var reviewStats: [AdminScenarioStat] {
        let m = scenario.metrics
        return [
            AdminScenarioStat(title: String(localized: "Reviewed sessions"), value: AdminScenarioFormat.count(m?.reviewedCount),
                              systemImage: "person.fill.checkmark"),
            AdminScenarioStat(title: String(localized: "Reviewed share"), value: AdminScenarioFormat.percent(m?.reviewedShare),
                              systemImage: "chart.pie"),
            AdminScenarioStat(title: String(localized: "Average rating"), value: AdminScenarioFormat.rating(m?.avgRating),
                              systemImage: "star"),
            AdminScenarioStat(title: String(localized: "Reported issues"), value: AdminScenarioFormat.count(m?.reportedIssueCount),
                              systemImage: "exclamationmark.bubble", tone: .warning),
        ]
    }

    var trendLabel: String? { scenario.metrics?.trend.map(AdminScenarioLabel.trend) }
    var maturityLabel: String? { scenario.metrics?.maturity.map(AdminScenarioLabel.maturity) }
    var confidenceLabel: String? { scenario.metrics?.forecastConfidence.map(AdminScenarioLabel.confidence) }

    /// Le righe dell'ultima sessione valutata.
    var lastSessionFields: [AdminAssetField] {
        var fields: [AdminAssetField] = []
        if let verdict = scenario.lastVerdict {
            fields.append(.init(title: String(localized: "Last verdict"), value: AdminScenarioLabel.verdict(verdict)))
        }
        if let date = scenario.lastAssessedAt {
            fields.append(.init(title: String(localized: "Assessed"), value: AdminScenarioFormat.date(date)))
        }
        if let date = scenario.updatedAt {
            fields.append(.init(title: String(localized: "Updated"), value: AdminScenarioFormat.date(date)))
        }
        return fields
    }
}
