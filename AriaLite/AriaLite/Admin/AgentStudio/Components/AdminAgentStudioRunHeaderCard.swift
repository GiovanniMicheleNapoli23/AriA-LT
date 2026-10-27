//
//  AdminAgentStudioRunHeaderCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  L'intestazione del run: titolo, modalità, stato, avanzamento determinato, tempo che scorre e passo in corso.
//

import SwiftUI

struct AdminAgentStudioRunHeaderCard: View {
    let viewModel: AdminAgentStudioRunViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(viewModel.title)
                    .font(.title3.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if let status = viewModel.statusForBadge { AdminAgentStudioBadge(status: status) }
            }
            if let mode = viewModel.modeChipText {
                AdminAgentStudioBadge(text: mode, tone: viewModel.isRealMode ? .warning : .neutral)
            }
            if viewModel.isActive || viewModel.progressFraction != nil { progress }
            if let usage = viewModel.usageText {
                Text(usage)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if viewModel.isActive, let step = viewModel.currentStepTitle { nowLine(step) }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: viewModel.progressFraction)
                .tint(Color.liteAccent)
                .accessibilityLabel("Progress")
                .accessibilityValue(viewModel.progressText ?? "")
            HStack(alignment: .firstTextBaseline) {
                if let text = viewModel.progressText {
                    Text(text).monospacedDigit()
                }
                Spacer(minLength: 8)
                elapsed
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    /// Il tempo scorre ogni secondo, ma solo finché il run è vivo.
    @ViewBuilder
    private var elapsed: some View {
        if viewModel.isActive, let start = viewModel.startedAt {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(AdminAgentStudioRunViewModel.elapsedText(context.date.timeIntervalSince(start)))
                    .monospacedDigit()
            }
        } else if let text = viewModel.finishedElapsedText {
            Text(text).monospacedDigit()
        }
    }

    private func nowLine(_ step: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.caption2)
                .foregroundStyle(Color.liteAccent)
                .symbolEffect(.pulse, isActive: !reduceMotion)
                .accessibilityHidden(true)
            Text("Now: \(step)")
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
