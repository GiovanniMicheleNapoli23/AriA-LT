//
//  AdminScenarioStepRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un passo della procedura come lo elenca il report: etichetta e titolo, esito e quanto riferito dall'operatore.
//

import SwiftUI

struct AdminScenarioStepRow: View {
    let step: AdminScenarioStep

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(step.headline.isEmpty ? String(localized: "Step") : step.headline)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if let outcome = step.outcomeLabel {
                    AdminScenarioBadge(text: outcome, tone: AdminScenarioLabel.stepOutcomeTone(step.outcome))
                }
            }
            if let report = step.operatorReport, !report.isEmpty {
                Text(report)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 6)
    }
}
