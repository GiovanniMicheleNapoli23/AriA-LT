//
//  AdminReasoningAttributionCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Da dove somiglia che venga la risposta: quante frasi hanno una fonte, per tipo di fonte, le fonti più
//  usate e ogni frase con la sua. Con la nota del server: somiglianza, non prova di derivazione.
//

import SwiftUI

struct AdminReasoningAttributionCard: View {
    let viewModel: AdminReasoningTurnViewModel

    @State private var showsSentences = false

    var body: some View {
        AdminCard(title: "Attribution", systemImage: "quote.bubble") {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if let message = viewModel.attributionError {
            VStack(alignment: .leading, spacing: 10) {
                AdminSectionNotice(text: message, systemImage: "info.circle", isError: !viewModel.attributionUnavailable)
                if !viewModel.attributionUnavailable {
                    Button("Retry") { Task { await viewModel.load() } }
                        .font(.subheadline.weight(.semibold))
                        .disabled(viewModel.isLoading)
                }
            }
        } else if viewModel.attribution == nil {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.attributionNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !viewModel.attributionStats.isEmpty { AdminReasoningStatGrid(stats: viewModel.attributionStats) }
                if !viewModel.kindBreakdown.isEmpty { kinds }
                if !viewModel.usedSpans.isEmpty { sources }
                if !viewModel.sentences.isEmpty { sentences }
            }
        }
    }

    private var kinds: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(viewModel.kindBreakdown, id: \.kind) { item in
                AdminFieldRow(field: AdminAssetField(title: item.kind, value: item.count.formatted()),
                              showsDivider: item.kind != viewModel.kindBreakdown.last?.kind)
            }
        }
    }

    private var sources: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sources used")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            ForEach(viewModel.usedSpans) { span in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "doc.text").foregroundStyle(Color.liteAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AdminReasoningFormat.trimmed(span.label) ?? span.slot ?? "—")
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        if let kind = span.kind {
                            Text(AdminReasoningFormat.humanize(kind))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    Text("\(span.hits ?? 0) sentences")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var sentences: some View {
        DisclosureGroup(isExpanded: $showsSentences) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(viewModel.sentences) { sentence in
                    AdminReasoningSentenceRow(sentence: sentence, source: viewModel.spanLabel(for: sentence),
                                              score: viewModel.scoreText(for: sentence))
                }
            }
            .padding(.top, 8)
        } label: {
            Text("Answer, sentence by sentence")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .tint(Color.liteAccent)
    }
}
