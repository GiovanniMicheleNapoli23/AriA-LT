//
//  AdminAlarmProposalCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La proposta dell'AI per l'allarme: ogni campo cambiato con la sua spunta e il valore proposto;
//  "Apply" scrive solo quelli scelti, "Discard" scarta tutto. Il testo libero della risposta sta sopra.
//

import SwiftUI

struct AdminAlarmProposalCard: View {
    @Bindable var viewModel: AdminAlarmImproveViewModel
    let proposal: AdminAlarmProposal

    var body: some View {
        AdminCard(title: "Proposal", systemImage: "sparkles") {
            VStack(alignment: .leading, spacing: 14) {
                if let text = proposal.text {
                    Text(verbatim: text)
                        .font(.subheadline)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let raw = proposal.raw {
                    Text(verbatim: raw).font(.caption.monospaced()).textSelection(.enabled).foregroundStyle(.secondary)
                }
                ForEach(proposal.changes) { change in
                    part(change)
                }
                if !proposal.changes.isEmpty { controls }
            }
        }
    }

    private func part(_ change: AdminAlarmProposal.Change) -> some View {
        let isOn = Binding(
            get: { viewModel.selected.contains(change.field) },
            set: { if $0 { viewModel.selected.insert(change.field) } else { viewModel.selected.remove(change.field) } })
        return VStack(alignment: .leading, spacing: 6) {
            Toggle(change.field.label, isOn: isOn)
                .font(.subheadline.weight(.semibold))
                .tint(Color.liteAccent)
                .disabled(viewModel.didApply)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(change.proposed.enumerated()), id: \.offset) { index, line in
                    Text(verbatim: change.field.isList ? "\(index + 1). \(line)" : line)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .opacity(isOn.wrappedValue ? 1 : 0.5)
            .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var controls: some View {
        if let error = viewModel.applyError {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.red)
        }
        if viewModel.didApply {
            Label("Applied to the alarm", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
        } else if viewModel.isApplying {
            ProgressView()
        } else {
            HStack(spacing: 12) {
                Button { Task { await viewModel.apply() } } label: {
                    Label("Apply", systemImage: "checkmark")
                }
                .ariaAccentGlassButtonStyle()
                .disabled(!viewModel.canApply)
                Button("Discard", role: .destructive) { viewModel.discard() }
                    .ariaGlassButtonStyle()
            }
        }
    }
}
