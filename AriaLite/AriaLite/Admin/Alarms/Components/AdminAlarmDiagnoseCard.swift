//
//  AdminAlarmDiagnoseCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda "Diagnosis" del dettaglio, con la sfera di Aria (è l'agente diagnostico): sopra il risultato
//  (AdminAlarmDiagnosisResult) o due righe su cosa fa, poi l'errore, il campo col contesto in più (facoltativo,
//  quindi sobrio) e sotto "Diagnose" a tutta larghezza: è l'azione della scheda.
//

import SwiftUI

struct AdminAlarmDiagnoseCard: View {
    @Bindable var viewModel: AdminAlarmDiagnosisViewModel
    @FocusState private var contextFocused: Bool

    var body: some View {
        AdminCard(ariaTitle: "Diagnosis") {
            VStack(alignment: .leading, spacing: 14) {
                if let diagnosis = viewModel.diagnosis {
                    AdminAlarmDiagnosisResult(diagnosis: diagnosis, viewModel: viewModel)
                    Divider()
                } else {
                    Text("Ask the diagnostic agent for the likely cause, the repair steps and the spare parts.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let failure = viewModel.failure {
                    Label(failure.message, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(Color.liteWarning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                bar
            }
            .animation(.snappy(duration: 0.22), value: viewModel.isRunning)
            .animation(.snappy(duration: 0.22), value: viewModel.failure?.message)
        }
    }

    private var bar: some View {
        VStack(spacing: 10) {
            TextField("Extra context (optional)", text: $viewModel.context, axis: .vertical)
                .lineLimit(1...5)
                .focused($contextFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .disabled(viewModel.isRunning)
            diagnoseButton
        }
    }

    private var diagnoseButton: some View {
        Button {
            contextFocused = false
            viewModel.diagnose()
        } label: {
            Group {
                if viewModel.isRunning {
                    HStack(spacing: 6) {
                        ProgressView().tint(Color.liteOnAccent)
                        Text("Diagnosing…")
                    }
                } else {
                    Label(viewModel.diagnosis == nil ? "Diagnose" : "Diagnose again", systemImage: "stethoscope")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 34)
        }
        .ariaAccentGlassButtonStyle()
        .buttonBorderShape(.capsule)
        .disabled(viewModel.isRunning)
    }
}
