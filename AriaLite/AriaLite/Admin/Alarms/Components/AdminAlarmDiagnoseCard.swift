//
//  AdminAlarmDiagnoseCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda "Diagnosis" del dettaglio, con la sfera di Aria (è l'agente diagnostico): sopra il risultato
//  (AdminAlarmDiagnosisResult) o due righe su cosa fa, poi l'errore e una barra come il composer della chat,
//  col contesto in più e "Diagnose" accanto. Con testo molto grande il pulsante va sotto il campo.
//

import SwiftUI

struct AdminAlarmDiagnoseCard: View {
    @Bindable var viewModel: AdminAlarmDiagnosisViewModel
    @FocusState private var contextFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// L'altezza di una riga della barra: il campo a riga singola e il pulsante hanno lo stesso centro.
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 36

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
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .trailing, spacing: 6) {
                    field
                    diagnoseButton
                }
            } else {
                HStack(alignment: .bottom, spacing: 6) {
                    field
                    diagnoseButton
                }
            }
        }
        .padding(5)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var field: some View {
        TextField("Extra context (optional)", text: $viewModel.context, axis: .vertical)
            .lineLimit(1...4)
            .focused($contextFocused)
            .padding(.leading, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: rowHeight, alignment: .leading)
            .disabled(viewModel.isRunning)
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
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: rowHeight - 8)
        }
        .ariaAccentGlassButtonStyle()
        .buttonBorderShape(.capsule)
        .fixedSize()
        .disabled(viewModel.isRunning)
    }
}
