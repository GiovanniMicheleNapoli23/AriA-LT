//
//  AdminMemoryFactDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un fatto: testo (tradotto, con l'originale a richiesta), chi l'ha proposto e quando,
//  quanto è affidabile, quanto lo usa Aria e da quale conversazione viene. Il fatto lo legge dalla lista,
//  così approva, rifiuta e modifica valgono subito per entrambe; le azioni sono quelle della lista.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminMemoryFactDetailViewModel {
    let list: AdminLearnedKnowledgeViewModel
    let factId: String
    /// Il testo originale al posto della traduzione, solo in questa schermata.
    var showsOriginal = false

    init(list: AdminLearnedKnowledgeViewModel, factId: String) {
        self.list = list
        self.factId = factId
    }

    /// `nil` dopo l'eliminazione: la vista torna indietro.
    var fact: AdminMemoryFact? { list.fact(id: factId) }

    // MARK: Testo

    func text(of fact: AdminMemoryFact) -> String {
        showsOriginal ? fact.content : list.displayText(for: fact)
    }

    /// C'è una traduzione per questo fatto: si offre "Show original" / "Show translation".
    func isTranslated(_ fact: AdminMemoryFact) -> Bool { list.isTranslated(fact) }

    /// "Fact · Learned from chat · Line 2": la riga sotto lo stato.
    func summaryLine(of fact: AdminMemoryFact) -> String {
        [fact.kind.map(AdminMemoryFactLabels.kind), fact.source.map(AdminMemoryFactLabels.source),
         list.plantName(fact.plantId)].compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: Schede

    /// Chi l'ha proposto e validato, e quando.
    func provenance(of fact: AdminMemoryFact) -> [AdminAssetField] {
        var rows: [AdminAssetField] = []
        func add(_ title: String, _ value: String?) {
            if let value, !value.isEmpty { rows.append(AdminAssetField(title: title, value: value)) }
        }
        add(String(localized: "Proposed by"), list.authorName(for: fact))
        add(String(localized: "Proposed on"), fact.createdAt?.formatted(date: .abbreviated, time: .shortened))
        add(String(localized: "Source"), fact.source.map(AdminMemoryFactLabels.source))
        add(String(localized: "Plant"), list.plantName(fact.plantId) ?? String(localized: "Whole company"))
        add(String(localized: "Category"), fact.category)
        add(String(localized: "Task"), fact.taskType.map(AdminMemoryFactLabels.readable))
        add(String(localized: "Validated by"), list.validatorName(for: fact))
        add(String(localized: "Approved on"), fact.approvedAt?.formatted(date: .abbreviated, time: .shortened))
        add(String(localized: "Last change"), fact.updatedAt?.formatted(date: .abbreviated, time: .shortened))
        return rows
    }

    /// Affidabilità: livello, fiducia (anche quella che cala col tempo) e confronto coi documenti.
    func reliability(of fact: AdminMemoryFact) -> [AdminAssetField] {
        var rows: [AdminAssetField] = []
        func add(_ title: String, _ value: String?) {
            if let value, !value.isEmpty { rows.append(AdminAssetField(title: title, value: value)) }
        }
        add(String(localized: "Trust"), fact.trustLevel.map(AdminMemoryFactLabels.trust))
        add(String(localized: "Confidence"), fact.confidence.map(Self.percent))
        if let decayed = fact.decayedConfidence, decayed != fact.confidence {
            add(String(localized: "Confidence today"), Self.percent(decayed))
        }
        add(String(localized: "Documents"), fact.truthVerdict.map(AdminMemoryFactLabels.verdict))
        return rows
    }

    private static func percent(_ value: Double) -> String {
        (value <= 1 ? value : value / 100).formatted(.percent.precision(.fractionLength(0)))
    }

    /// Quante volte Aria l'ha usato e se è servito.
    func usage(of fact: AdminMemoryFact) -> [AdminMemoryFactStat] {
        [AdminMemoryFactStat(title: String(localized: "Used"), value: fact.hitCount.formatted(), systemImage: "arrow.triangle.2.circlepath"),
         AdminMemoryFactStat(title: String(localized: "Helpful"), value: fact.helpCount.formatted(), systemImage: "hand.thumbsup"),
         AdminMemoryFactStat(title: String(localized: "Not helpful"), value: fact.missCount.formatted(), systemImage: "hand.thumbsdown")]
    }

    func lastUsedLine(of fact: AdminMemoryFact) -> String? {
        fact.lastUsedAt.map { String(localized: "Last used \($0.formatted(.relative(presentation: .named)))") }
    }

    func hasConversation(_ fact: AdminMemoryFact) -> Bool {
        fact.sourceQuestion != nil || fact.sourceAnswerSummary != nil || fact.sourceAnswer != nil
    }

    /// La risposta di Aria da cui viene il fatto: il riassunto se c'è, altrimenti la risposta intera.
    func answer(of fact: AdminMemoryFact) -> String? { fact.sourceAnswerSummary ?? fact.sourceAnswer }

    func hasReliabilityNotes(_ fact: AdminMemoryFact) -> Bool {
        fact.conflictingEvidence != nil || !fact.evidence.isEmpty
    }

    // MARK: Azioni

    func isBusy(_ fact: AdminMemoryFact) -> Bool { list.isBusy(fact) }
    func canApprove(_ fact: AdminMemoryFact) -> Bool { list.canApprove(fact) }
    func canReject(_ fact: AdminMemoryFact) -> Bool { list.canReject(fact) }

    func approve(_ fact: AdminMemoryFact) async { await list.approve(fact) }
    func askToReject(_ fact: AdminMemoryFact) { list.askToReject(fact) }
    func askToDelete(_ fact: AdminMemoryFact) { list.askToDelete(fact) }

    func makeEditForm(for fact: AdminMemoryFact) -> AdminMemoryFactFormViewModel { list.makeEditForm(for: fact) }
    func saved(_ fact: AdminMemoryFact) { list.apply(fact) }
}

/// Un numero della scheda "Usage".
nonisolated struct AdminMemoryFactStat: Sendable, Hashable, Identifiable {
    let title: String
    let value: String
    let systemImage: String
    var id: String { title }
}
