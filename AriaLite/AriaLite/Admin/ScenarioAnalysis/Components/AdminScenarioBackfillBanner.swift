//
//  AdminScenarioBackfillBanner.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo stato del backfill in cima agli scenari: in corso (con Stop), finito, fermato o interrotto (con il motivo).
//

import SwiftUI

struct AdminScenarioBackfillBanner: View {
    let viewModel: AdminScenarioBackfillViewModel

    var body: some View {
        if viewModel.phase != .idle {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    if viewModel.isRunning {
                        ProgressView()
                    } else {
                        Image(systemName: viewModel.resultSystemImage).foregroundStyle(viewModel.resultTone.color)
                    }
                    Text(viewModel.title)
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    if viewModel.isRunning {
                        Button("Stop") { viewModel.stop() }
                            .font(.subheadline.weight(.semibold))
                    } else {
                        Button("Dismiss", systemImage: "xmark") { withAnimation(.snappy) { viewModel.dismiss() } }
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(viewModel.progressText)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                if let optedOut = viewModel.optedOutText {
                    Text(optedOut).font(.footnote).foregroundStyle(.secondary)
                }
                if let message = viewModel.errorMessage {
                    Text(message).font(.footnote).foregroundStyle(.orange)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
        }
    }
}
