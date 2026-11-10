//
//  AdminAlarmProposalSections.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La proposta dell'AI per l'allarme, come sezioni di un Form: il testo libero della risposta, ogni campo
//  cambiato con la sua spunta e il valore proposto, poi "Apply" (solo i campi scelti) e "Discard".
//

import SwiftUI

struct AdminAlarmProposalSections: View {
    @Bindable var viewModel: AdminAlarmImproveViewModel
    let proposal: AdminAlarmProposal

    var body: some View {
        if proposal.text != nil || proposal.raw != nil {
            Section("Proposal") {
                if let text = proposal.text {
                    Text(verbatim: text).textSelection(.enabled)
                }
                if let raw = proposal.raw {
                    Text(verbatim: raw)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        if !proposal.changes.isEmpty {
            Section {
                ForEach(proposal.changes) { change in
                    row(change)
                }
            } header: {
                Text("Changes")
            } footer: {
                Text("Only the selected fields are written to the alarm.")
            }
            Section { controls }
        }
    }

    private func row(_ change: AdminAlarmProposal.Change) -> some View {
        let isOn = Binding(
            get: { viewModel.selected.contains(change.field) },
            set: { if $0 { viewModel.selected.insert(change.field) } else { viewModel.selected.remove(change.field) } })
        return Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: change.field.label)
                ForEach(Array(change.proposed.enumerated()), id: \.offset) { index, line in
                    Text(verbatim: change.field.isList ? "\(index + 1). \(line)" : line)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(viewModel.didApply)
    }

    @ViewBuilder
    private var controls: some View {
        if let error = viewModel.applyError {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(.red)
        }
        if viewModel.didApply {
            Label("Applied to the alarm", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            Button { Task { await viewModel.apply() } } label: {
                HStack {
                    Label("Apply", systemImage: "checkmark")
                    Spacer()
                    if viewModel.isApplying { ProgressView() }
                }
            }
            .tint(Color.liteAccent)
            .disabled(!viewModel.canApply)
            Button("Discard", systemImage: "xmark", role: .destructive) { viewModel.discard() }
                .disabled(viewModel.isApplying)
        }
    }
}
