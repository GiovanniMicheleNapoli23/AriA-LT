//
//  AdminAgentStudioPreflightCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  I controlli prima del run (connettori e policy): spunta, avviso o errore con il messaggio. Si apre da solo se qualcosa non è passato.
//

import SwiftUI

struct AdminAgentStudioPreflightCard: View {
    let checks: [AdminAgentStudioLiveRun.Check]
    let startsExpanded: Bool

    var body: some View {
        AdminAgentStudioDisclosureCard(title: "Pre-flight checks", systemImage: "checklist", startsExpanded: startsExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(checks) { check in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: symbol(check.verdict))
                            .font(.subheadline)
                            .foregroundStyle(tint(check.verdict))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(check.name).font(.subheadline.weight(.semibold))
                            if let message = check.message {
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(label(check.verdict)), \(check.name)")
                    .accessibilityValue(check.message ?? "")
                }
            }
        }
    }

    private func symbol(_ verdict: AdminAgentStudioLiveRun.Check.Verdict) -> String {
        switch verdict {
        case .passed: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .failed: "xmark.circle.fill"
        }
    }

    private func tint(_ verdict: AdminAgentStudioLiveRun.Check.Verdict) -> Color {
        switch verdict {
        case .passed: .green
        case .warning: .orange
        case .failed: .red
        }
    }

    private func label(_ verdict: AdminAgentStudioLiveRun.Check.Verdict) -> String {
        switch verdict {
        case .passed: String(localized: "Passed")
        case .warning: String(localized: "Warning")
        case .failed: String(localized: "Failed")
        }
    }
}
