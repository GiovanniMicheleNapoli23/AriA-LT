//
//  AdminDocumentRunRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una run di pipeline nel dettaglio: tipo, stato, quando e quanto è durata, i risultati
//  (chunk, entità estratte, classificazione) e l'eventuale errore o fase fallita.
//

import SwiftUI

struct AdminDocumentRunRow: View {
    let run: AdminDocumentRun
    var showsDivider = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(run.pipelineLabel)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                if run.isActive { ProgressView().controlSize(.mini) }
                Text(run.stateLabel)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(run.stateTint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(run.stateTint.opacity(0.14), in: Capsule())
                    .fixedSize()
            }
            if !timeLine.isEmpty {
                Text(timeLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !results.isEmpty {
                Text(results)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let failedStage = run.stages.first(where: \.isFailed) {
                Label(failedStage.error.map { "\(failedStage.label): \($0)" } ?? failedStage.label,
                      systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let error = run.error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(run.warnings.prefix(3), id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if showsDivider { Divider().padding(.top, 6) }
        }
        .accessibilityElement(children: .combine)
    }

    /// "22 Oct, 10:41 · 2 min 5 s"
    private var timeLine: String {
        var parts: [String] = []
        if let start = run.startedAt ?? run.createdAt { parts.append(start.formatted(date: .abbreviated, time: .shortened)) }
        if let duration = run.duration { parts.append(duration.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2))) }
        return parts.joined(separator: " · ")
    }

    /// "120 chunks · 8 items extracted · Manual (92%)"
    private var results: String {
        var parts: [String] = []
        if let chunks = run.chunksCreated { parts.append(String(localized: "\(chunks) chunks")) }
        if let entities = run.entitiesExtracted { parts.append(String(localized: "\(entities) items extracted")) }
        if let kind = run.classification.first {
            let confidence = run.classificationConfidence.map { " (\($0.formatted(.percent.precision(.fractionLength(0)))))" } ?? ""
            parts.append(AdminDocumentState.label(for: kind) + confidence)
        }
        return parts.joined(separator: " · ")
    }
}
