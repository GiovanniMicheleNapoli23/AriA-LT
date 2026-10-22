//
//  AdminWorkflowValidationCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'esito del controllo del flusso: valido o no, poi errori (bloccano la pubblicazione) e avvisi.
//  Ogni problema dice quale passo riguarda, se il server lo indica.
//

import SwiftUI

struct AdminWorkflowValidationCard: View {
    let validation: AdminWorkflowValidation
    let nodeTitle: (String?) -> String?

    var body: some View {
        AdminCard(title: "Check", systemImage: "checkmark.shield") {
            VStack(alignment: .leading, spacing: 12) {
                if validation.valid {
                    Label("The flow is valid and can be published.", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                } else {
                    Label("The flow has errors and can't be published yet.", systemImage: "xmark.octagon.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                }
                issues(validation.errors, systemImage: "xmark.circle.fill", tint: .red)
                issues(validation.warnings, systemImage: "exclamationmark.triangle.fill", tint: .orange)
            }
        }
    }

    private func issues(_ list: [AdminWorkflowIssue], systemImage: String, tint: Color) -> some View {
        ForEach(Array(list.enumerated()), id: \.offset) { _, issue in
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(issue.message.isEmpty ? issue.code : issue.message)
                        .font(.footnote)
                        .multilineTextAlignment(.leading)
                    if let node = nodeTitle(issue.nodeId) {
                        Text(node)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
