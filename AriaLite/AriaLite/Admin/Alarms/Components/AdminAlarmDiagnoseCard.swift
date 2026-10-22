//
//  AdminAlarmDiagnoseCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda "Diagnose" del dettaglio: un campo per il contesto in più, il pulsante, il caricamento,
//  l'errore e, sotto, il risultato (AdminAlarmDiagnosisResult).
//

import SwiftUI

struct AdminAlarmDiagnoseCard: View {
    @Bindable var viewModel: AdminAlarmDiagnosisViewModel

    var body: some View {
        AdminCard(title: "Diagnosis", systemImage: "stethoscope") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Ask the diagnostic agent for the likely cause, the repair steps and the spare parts.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextField("Extra context (optional)", text: $viewModel.context, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .disabled(viewModel.isRunning)
                if viewModel.isRunning {
                    ProgressView("Diagnosing…").frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Button { viewModel.diagnose() } label: {
                        Label(viewModel.diagnosis == nil ? "Diagnose" : "Diagnose again", systemImage: "stethoscope")
                    }
                    .ariaAccentGlassButtonStyle()
                }
                if let failure = viewModel.failure {
                    Label(failure.message, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let diagnosis = viewModel.diagnosis {
                    Divider()
                    AdminAlarmDiagnosisResult(diagnosis: diagnosis, viewModel: viewModel)
                }
            }
        }
    }
}
