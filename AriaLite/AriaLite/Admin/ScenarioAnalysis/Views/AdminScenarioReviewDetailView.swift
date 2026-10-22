//
//  AdminScenarioReviewDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di una sessione rivista: verdetto e fonte (correggibile), segnali dell'operatore, passi,
//  traccia del feedback con le note dell'admin, cose imparate e il report .docx della procedura.
//

import SwiftUI

struct AdminScenarioReviewDetailView: View {
    @State private var viewModel: AdminScenarioReviewDetailViewModel

    @State private var reviewForm: AdminScenarioReviewFormViewModel?
    @State private var noteForm: AdminScenarioNoteFormViewModel?

    init(viewModel: AdminScenarioReviewDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                verdictCard
                AdminCard(title: "Operator signals", systemImage: "waveform.path.ecg") {
                    AdminScenarioStatGrid(stats: viewModel.signals)
                }
                if !viewModel.steps.isEmpty { stepsCard }
                trailCard
                if !viewModel.learned.isEmpty { learnedCard }
                AdminCard(title: "Report", systemImage: "doc.text") {
                    AdminScenarioReportButton(viewModel: viewModel.report)
                }
            }
            .padding(20)
            .ariaReadableWidth()
        }
        .liteBackground()
        .navigationTitle(viewModel.review.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Actions", systemImage: "ellipsis.circle") {
                    Button("Correct verdict", systemImage: "checkmark.seal") { reviewForm = viewModel.makeReviewForm() }
                    Button("Add note", systemImage: "note.text.badge.plus") { noteForm = viewModel.makeNoteForm() }
                }
            }
        }
        .refreshable { await viewModel.reviews.load() }
        .sheet(item: $reviewForm) { AdminScenarioReviewFormView(viewModel: $0) }
        .sheet(item: $noteForm) { AdminScenarioNoteFormView(viewModel: $0) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let code = viewModel.review.alarmCode {
                Text(code)
                    .font(.subheadline.weight(.bold).monospaced())
                    .foregroundStyle(Color.liteAccent)
            }
            Text(viewModel.review.displayTitle)
                .font(.title3.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            if let episode = viewModel.episodeLabel {
                Text(episode).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var verdictCard: some View {
        AdminCard(title: "Verdict", systemImage: "checkmark.seal") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    AdminScenarioBadge(text: viewModel.verdictLabel, tone: AdminScenarioLabel.verdictTone(viewModel.review.verdict))
                    if let source = viewModel.sourceLabel {
                        AdminScenarioBadge(text: source, tone: viewModel.isHumanVerdict ? .info : .neutral,
                                           systemImage: viewModel.isHumanVerdict ? "person.fill" : "sparkles")
                    }
                }
                if !viewModel.isHumanVerdict {
                    Text("This verdict rests only on Aria's reading of the conversation. Correct it if you know how it really ended.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                let fields = viewModel.verdictFields
                if !fields.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(fields) { field in
                            AdminFieldRow(field: field, showsDivider: field.id != fields.last?.id)
                        }
                    }
                }
                if let issues = viewModel.review.reviewIssues, !issues.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reported issues").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(issues).font(.subheadline).textSelection(.enabled)
                    }
                }
                Button {
                    reviewForm = viewModel.makeReviewForm()
                } label: {
                    Label("Correct verdict", systemImage: "pencil")
                }
                .ariaGlassButtonStyle()
            }
        }
    }

    private var stepsCard: some View {
        AdminCard(title: "Steps", systemImage: "list.number") {
            VStack(alignment: .leading, spacing: 0) {
                let steps = viewModel.steps
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    AdminScenarioStepRow(step: step)
                    if index < steps.count - 1 { Divider() }
                }
            }
        }
    }

    private var trailCard: some View {
        AdminCard(title: "Feedback trail", systemImage: "text.bubble") {
            Button("Add note", systemImage: "plus") { noteForm = viewModel.makeNoteForm() }
                .labelStyle(.iconOnly)
                .font(.subheadline.weight(.semibold))
        } content: {
            let events = viewModel.feedback
            if events.isEmpty {
                AdminSectionNotice(text: String(localized: "No feedback on this procedure yet."))
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(events) { event in
                        AdminScenarioTrailRow(event: event)
                        if event.id != events.last?.id { Divider() }
                    }
                }
            }
        }
    }

    private var learnedCard: some View {
        AdminCard(title: "What Aria learned", systemImage: "lightbulb") {
            VStack(alignment: .leading, spacing: 0) {
                let learned = viewModel.learned
                ForEach(learned) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.content)
                            .font(.subheadline)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 6) {
                            if let kind = item.kind { AdminScenarioBadge(text: AdminScenarioLabel.humanized(kind), tone: .info) }
                            if let status = item.status { AdminScenarioBadge(text: AdminScenarioLabel.humanized(status)) }
                        }
                    }
                    .padding(.vertical, 8)
                    if item.id != learned.last?.id { Divider() }
                }
            }
        }
    }
}
