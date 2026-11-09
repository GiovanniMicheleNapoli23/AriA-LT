//
//  AdminScenarioDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di uno scenario: riassunto, affidabilità e previsione, esiti delle sessioni, revisioni,
//  fatti imparati usati e l'ultima sessione con il suo report. I testi si mostrano tradotti, l'originale a un tocco.
//

import SwiftUI

struct AdminScenarioDetailView: View {
    @State private var viewModel: AdminScenarioDetailViewModel

    init(viewModel: AdminScenarioDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if viewModel.summary != nil || viewModel.descriptionText != nil { summaryCard }
                AdminCard(title: "Reliability", systemImage: "checkmark.seal") {
                    VStack(alignment: .leading, spacing: 10) {
                        if let confidence = viewModel.confidenceLabel {
                            Text(confidence).font(.footnote).foregroundStyle(.secondary)
                        }
                        AdminScenarioStatGrid(stats: viewModel.reliabilityStats)
                    }
                }
                AdminCard(title: "Outcomes", systemImage: "chart.bar") {
                    VStack(alignment: .leading, spacing: 12) {
                        AdminScenarioOutcomeBar(resolved: viewModel.scenario.successCount ?? 0,
                                                unresolved: viewModel.scenario.failureCount ?? 0,
                                                unclear: viewModel.scenario.unclearCount ?? 0)
                        AdminScenarioStatGrid(stats: viewModel.outcomeStats)
                    }
                }
                AdminCard(title: "Human review", systemImage: "person.fill.checkmark") {
                    AdminScenarioStatGrid(stats: viewModel.reviewStats)
                }
                if !viewModel.scenario.facts.isEmpty { factsCard }
                if let report = viewModel.lastReport { lastSessionCard(report) }
            }
            .padding(20)
            .ariaReadableWidth()
        }
        .liteBackground()
        .navigationTitle(viewModel.scenario.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.hasTranslations {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showsOriginal.toggle()
                    } label: {
                        if viewModel.showsOriginal {
                            Label("Show translation", systemImage: "character.bubble")
                        } else {
                            Label("Show original", systemImage: "character.bubble.fill")
                        }
                    }
                }
            }
        }
        .task { await viewModel.translate() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let kind = viewModel.kindLabel {
                    AdminScenarioBadge(text: kind, tone: .info,
                                       systemImage: AdminScenarioKind.systemImage(for: viewModel.scenario.kind))
                }
                if let code = viewModel.scenario.alarmCode {
                    Text(code)
                        .font(.subheadline.weight(.bold).monospaced())
                        .foregroundStyle(Color.liteAccent)
                }
            }
            Text(viewModel.scenario.displayTitle)
                .font(.title3.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                if let trend = viewModel.trendLabel {
                    AdminScenarioBadge(text: trend, tone: AdminScenarioLabel.trendTone(viewModel.scenario.metrics?.trend),
                                       systemImage: AdminScenarioLabel.trendSystemImage(viewModel.scenario.metrics?.trend))
                }
                if let maturity = viewModel.maturityLabel {
                    AdminScenarioBadge(text: maturity, tone: AdminScenarioLabel.maturityTone(viewModel.scenario.metrics?.maturity))
                }
            }
        }
    }

    private var summaryCard: some View {
        AdminCard(title: "Summary", systemImage: "text.alignleft") {
            VStack(alignment: .leading, spacing: 10) {
                if let summary = viewModel.summary {
                    Text(summary).font(.subheadline).textSelection(.enabled)
                }
                if let description = viewModel.descriptionText {
                    Text(description).font(.subheadline).foregroundStyle(.secondary).textSelection(.enabled)
                }
                if viewModel.isTranslating {
                    Label("Translating…", systemImage: "character.bubble")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var factsCard: some View {
        AdminCard(title: "Learned facts used", systemImage: "lightbulb") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(viewModel.scenario.facts.enumerated()), id: \.element.id) { index, fact in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.content(of: fact))
                            .font(.subheadline)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 6) {
                            if let status = fact.status {
                                AdminScenarioBadge(text: AdminScenarioLabel.humanized(status))
                            }
                            if let hits = fact.hitCount, hits > 0 {
                                Text("Used \(hits) times").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 10)
                    if index < viewModel.scenario.facts.count - 1 { Divider() }
                }
            }
        }
    }

    private func lastSessionCard(_ report: AdminScenarioReportViewModel) -> some View {
        AdminCard(title: "Last session", systemImage: "clock.arrow.circlepath") {
            VStack(alignment: .leading, spacing: 12) {
                let fields = viewModel.lastSessionFields
                if !fields.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(fields) { field in
                            AdminFieldRow(field: field, showsDivider: field.id != fields.last?.id)
                        }
                    }
                }
                AdminScenarioReportButton(viewModel: report)
            }
        }
    }
}
